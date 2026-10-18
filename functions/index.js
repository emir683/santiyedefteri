/**
 * Firebase Cloud Functions — Şantiye Puantaj Defteri
 *
 * 1. onHistoryWrite: İşlem geçmişine yeni kayıt gelince ilgili kişilere
 *    FCM push bildirimi gönderir (uygulama kapalı olsa bile çalışır).
 *
 * 2. onWeeklySummary: Her Pazartesi 08:00 (Türkiye saati) ekip kurucularına
 *    haftalık özet bildirimi gönderir.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const fcm = getMessaging();

// ─── CAD HAZIR PUSH BİLDİRİMİ (UYGULAMA TAMAMEN KAPALIYKEN BİLE ÇALIŞIR) ─────
exports.notifyCadReady = onRequest(
  {
    region: 'europe-west1',
    cors: true,
  },
  async (req, res) => {
    try {
      const { fcmToken, projectName, webglUrl, fileId } = req.body || {};
      if (!fcmToken) {
        return res.status(400).json({ error: 'fcmToken parametresi gerekli' });
      }

      const baslik = projectName || 'CAD Projesi';
      console.log(`📡 [CAD PUSH] Gönderiliyor: ${baslik} (${fileId}) -> ${fcmToken.substring(0, 15)}...`);

      await fcm.send({
        token: fcmToken,
        notification: {
          title: `📐 ${baslik} Çizimi Hazır!`,
          body: 'Çizim başarıyla çözümlendi, 3D/2D CAD görüntüleyiciyi açmak için dokunun.',
        },
        data: {
          action: 'cad_project',
          webgl_url: webglUrl || '',
          project_name: baslik,
          file_id: fileId || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'santiye_bildirim_kanali',
            icon: 'notification_icon',
            color: '#14B8A6',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
      });

      console.log(`✅ [CAD PUSH SUCCESS] Bildirim başarıyla iletildi: ${fileId}`);
      return res.json({ success: true, fileId });
    } catch (err) {
      console.error('❌ [CAD PUSH ERROR]', err);
      return res.status(500).json({ error: err.message });
    }
  }
);

// ─── 1. HISTORY TRIGGER ─────────────────────────────────────────────────────

/**
 * teams/{teamId}/history/{docId} koleksiyonuna yeni belge yazılınca tetiklenir.
 * İlgili kullanıcılara FCM push bildirimi gönderir.
 */
exports.onHistoryWrite = onDocumentCreated(
  {
    document: 'teams/{teamId}/history/{docId}',
    region: 'europe-west1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const teamId = event.params.teamId;

    const islemTipi = data.islemTipi || '';
    const detaylar = data.detaylar || {};
    const islemYapanUid = data.kullaniciUid || '';
    const islemYapanUsername = data.kullaniciUsername || 'Biri';

    // Ekip bilgilerini al
    const teamDoc = await db.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return;

    const teamData = teamDoc.data();
    const kurucuUid = teamData.kurucu || '';
    const yoneticiler = Array.isArray(teamData.yoneticiler)
      ? teamData.yoneticiler
      : [];

    // Bildirim alacak kişiler
    const hedefUidler = new Set([kurucuUid, ...yoneticiler]);
    hedefUidler.delete(islemYapanUid); // Kendi işlemini kendine gönderme

    // İşçiye bağlı kullanıcı varsa ekle
    const isciAdi = detaylar.isciAdi;
    if (isciAdi) {
      const workerSnap = await db
        .collection('teams')
        .doc(teamId)
        .collection('workers')
        .where('ad', '==', isciAdi)
        .limit(1)
        .get();

      if (!workerSnap.empty) {
        const workerData = workerSnap.docs[0].data();
        const linkedUid = workerData.linkedUserId;
        if (linkedUid && linkedUid !== islemYapanUid) {
          hedefUidler.add(linkedUid);
        }
      }
    }

    if (hedefUidler.size === 0) return;

    // FCM token'larını topla
    const tokens = [];
    const hedefArray = Array.from(hedefUidler);

    for (const uid of hedefArray) {
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) continue;
      const userData = userDoc.data();
      const token = userData.fcmToken;
      const islemBildirimleriAktif = userData.islemBildirimleriAktif !== false; // varsayılan true
      if (token && islemBildirimleriAktif) tokens.push(token);
    }

    if (tokens.length === 0) return;

    // Bildirim mesajını oluştur
    const { title, body } = buildNotificationMessage(
      islemTipi,
      detaylar,
      islemYapanUsername
    );

    // FCM MultiCast gönder
    const message = {
      notification: { title, body },
      data: {
        teamId,
        islemTipi,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        notification: {
          channelId: 'santiye_bildirim_kanali',
          icon: 'notification_icon',
          color: '#14B8A6',
          priority: 'high',
        },
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: 'default',
          },
        },
      },
      tokens,
    };

    try {
      const response = await fcm.sendEachForMulticast(message);
      console.log(
        `✅ FCM gönderildi: ${response.successCount} başarılı, ${response.failureCount} başarısız`
      );

      // Başarısız token'ları temizle
      response.responses.forEach(async (resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            // Token geçersiz, kullanıcı kaydından sil
            const invalidUid = hedefArray[idx];
            if (invalidUid) {
              await db.collection('users').doc(invalidUid).update({
                fcmToken: null,
              });
            }
          }
        }
      });
    } catch (err) {
      console.error('FCM gönderme hatası:', err);
    }
  }
);

// ─── 2. HAFTALIK ÖZET ────────────────────────────────────────────────────────

/**
 * Her Pazartesi sabahı 08:00 Türkiye saati (UTC+3 → 05:00 UTC)
 * ekip kurucularına haftalık özet bildirimi gönderir.
 */
exports.onWeeklySummary = onSchedule(
  {
    schedule: '0 5 * * 1', // Her Pazartesi 05:00 UTC = 08:00 TR
    timeZone: 'Europe/Istanbul',
    region: 'europe-west1',
  },
  async () => {
    const simdi = new Date();
    const gecenHaftaBaslangic = new Date(simdi);
    gecenHaftaBaslangic.setDate(simdi.getDate() - 7);

    const teamsSnap = await db.collection('teams').get();

    for (const teamDoc of teamsSnap.docs) {
      try {
        const teamData = teamDoc.data();
        const kurucuUid = teamData.kurucu;
        if (!kurucuUid) continue;

        // Geçen haftanın rapor sayısı
        const raporSnap = await db
          .collection('teams')
          .doc(teamDoc.id)
          .collection('reports')
          .where('tarih', '>=', Timestamp.fromDate(gecenHaftaBaslangic))
          .get();

        const raporSayisi = raporSnap.size;
        if (raporSayisi === 0) continue;

        // Kurucu FCM token'ı
        const kurucuDoc = await db.collection('users').doc(kurucuUid).get();
        if (!kurucuDoc.exists) continue;
        const token = kurucuDoc.data().fcmToken;
        if (!token) continue;

        await fcm.send({
          token,
          notification: {
            title: '📊 Haftalık Şantiye Özeti',
            body: `Geçen hafta ${raporSayisi} rapor girildi. Detayları görmek için aç!`,
          },
          data: {
            teamId: teamDoc.id,
            islemTipi: 'HAFTALIK_OZET',
          },
          android: {
            notification: {
              channelId: 'santiye_bildirim_kanali',
              icon: 'notification_icon',
              color: '#14B8A6',
            },
          },
          apns: {
            payload: { aps: { badge: 1, sound: 'default' } },
          },
        });

        console.log(`✅ Haftalık özet gönderildi: ${teamDoc.id}`);
      } catch (err) {
        console.error(`Haftalık özet hatası (${teamDoc.id}):`, err);
      }
    }
  }
);

// ─── YARDIMCI FONKSİYONLAR ───────────────────────────────────────────────────

/**
 * İşlem tipine göre Türkçe bildirim başlığı ve gövdesi oluşturur.
 */
function buildNotificationMessage(islemTipi, detaylar, username) {
  switch (islemTipi) {
    case 'ISCI_EKLEME':
      return {
        title: '👷 Yeni İşçi Eklendi',
        body: `${username}, ${detaylar.isciAdi || 'bir işçiyi'} ekibe ekledi.`,
      };
    case 'ISCI_GUNCELLEME':
      return {
        title: '✏️ İşçi Bilgileri Güncellendi',
        body: `${username}, ${detaylar.isciAdi || 'bir işçinin'} bilgilerini güncelledi.`,
      };
    case 'ISCI_SILME':
      return {
        title: '🗑️ İşçi Silindi',
        body: `${username} bir işçiyi ekipten çıkardı.`,
      };
    case 'SANTIYE_EKLEME':
      return {
        title: '🏗️ Yeni Şantiye',
        body: `${username}, ${detaylar.santiyeAdi || 'yeni bir'} şantiyesi ekledi.`,
      };
    case 'SANTIYE_SILME':
      return {
        title: '🗑️ Şantiye Silindi',
        body: `${username}, ${detaylar.santiyeAdi || 'bir'} şantiyesini sildi.`,
      };
    case 'GUNLUK_RAPOR_EKLEME':
      return {
        title: '📋 Günlük Rapor Girildi',
        body: `${username}, ${detaylar.santiyeAdi || ''} şantiyesine rapor girdi.`,
      };
    case 'GUNLUK_RAPOR_GUNCELLEME':
      return {
        title: '📝 Rapor Güncellendi',
        body: `${username}, ${detaylar.santiyeAdi || ''} raporunu güncelledi.`,
      };
    case 'ODEME_EKLEME':
      return {
        title: '💰 Ödeme Kaydedildi',
        body: `${username}, ${detaylar.miktar} TL ödeme kaydetti.`,
      };
    case 'AVANS_EKLEME':
      return {
        title: '💳 Avans Verildi',
        body: `${username}, ${detaylar.isci || 'bir işçiye'} ${detaylar.miktar} TL avans verdi.`,
      };
    case 'ROL_DEGISIMI':
      return {
        title: '🔑 Rol Değişikliği',
        body: `${username} ekipte rol değişikliği yaptı.`,
      };
    default:
      return {
        title: '🏗️ Şantiye Defteri',
        body: `${username} bir işlem gerçekleştirdi.`,
      };
  }
}
