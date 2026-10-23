/**
 * Firebase Cloud Functions — Şantiye Puantaj Defteri
 *
 * 1. notifyCadReady: CAD çizimi tamamlandığında uzaktan FCM push bildirimi gönderir.
 * 2. onHistoryWrite: İşlem geçmişine yeni kayıt gelince (rapor, işçi, ödeme, yetki, üye katılımı)
 *    kategori tercihlerine göre ilgili kişilere anlık bildirim iletir.
 * 3. onDailyPuantajReminder: Her gün 20:00 (Türkiye saati) rapor girilmemiş şantiyeler için akıllı uyarı atar.
 * 4. onWeeklySummary: Her Pazartesi 09:00 (Türkiye saati) ekip kurucularına haftalık özet bildirimi gönderir.
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
 * İlgili kullanıcılara kategori tercihlerine göre FCM push bildirimi gönderir.
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

    // 1. Rol değişikliğinde hedef kullanıcıya bildir
    if (islemTipi === 'ROL_DEGISIMI' && detaylar.uyeUid) {
      if (detaylar.uyeUid !== islemYapanUid) {
        hedefUidler.add(detaylar.uyeUid);
      }
    }

    // 2. İşçi kartı eşleştiğinde hedef kullanıcıya bildir
    if (islemTipi === 'ISCI_KART_ESLESMESI' && detaylar.targetUserId) {
      if (detaylar.targetUserId !== islemYapanUid) {
        hedefUidler.add(detaylar.targetUserId);
      }
    }

    // 3. İşçiye bağlı kullanıcı varsa ekle
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

    // FCM token'larını kategori tercihlerine göre topla
    const tokens = [];
    const hedefArray = Array.from(hedefUidler);

    for (const uid of hedefArray) {
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) continue;
      const userData = userDoc.data();
      const token = userData.fcmToken;
      const islemBildirimleriAktif = userData.islemBildirimleriAktif !== false;

      // Kategori bazlı filtreleme
      let categoryAllowed = true;
      if (islemTipi.startsWith('ODEME') || islemTipi.startsWith('AVANS')) {
        categoryAllowed = userData.odemeBildirimleriAktif !== false;
      } else if (islemTipi.startsWith('GUNLUK_RAPOR')) {
        categoryAllowed = userData.puantajHatirlaticiAktif !== false;
      } else if (
        islemTipi === 'EKIBE_KATILIM' ||
        islemTipi === 'ROL_DEGISIMI' ||
        islemTipi === 'ISCI_KART_ESLESMESI' ||
        islemTipi === 'UYE_CIKARMA'
      ) {
        categoryAllowed = userData.ekipBildirimleriAktif !== false;
      }

      if (token && islemBildirimleriAktif && categoryAllowed) {
        tokens.push(token);
      }
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

// ─── 2. AKILLI EKSİK PUANTAJ VE RAPOR HATIRLATICISI (HER GÜN 20:00 TR) ──────

exports.onDailyPuantajReminder = onSchedule(
  {
    schedule: '0 20 * * *', // Her gün 20:00 Türkiye Saati
    timeZone: 'Europe/Istanbul',
    region: 'europe-west1',
  },
  async () => {
    const simdi = new Date();
    const bugunBaslangic = new Date(simdi.getFullYear(), simdi.getMonth(), simdi.getDate(), 0, 0, 0);

    const teamsSnap = await db.collection('teams').get();

    for (const teamDoc of teamsSnap.docs) {
      try {
        const teamData = teamDoc.data();
        if (teamData.isPersonal) continue;

        // Bugün bu ekibe herhangi bir rapor girilmiş mi?
        const reportsSnap = await db
          .collection('teams')
          .doc(teamDoc.id)
          .collection('reports')
          .where('tarih', '>=', Timestamp.fromDate(bugunBaslangic))
          .limit(1)
          .get();

        if (!reportsSnap.empty) continue; // Bugün zaten girilmiş, uyarılmayacak

        // Kurucu ve yöneticileri bul
        const kurucuUid = teamData.kurucu;
        const yoneticiler = Array.isArray(teamData.yoneticiler) ? teamData.yoneticiler : [];
        const targetUids = new Set([kurucuUid, ...yoneticiler]);

        for (const uid of targetUids) {
          if (!uid) continue;
          const userDoc = await db.collection('users').doc(uid).get();
          if (!userDoc.exists) continue;
          const uData = userDoc.data();
          const token = uData.fcmToken;
          const puantajAktif =
            uData.puantajHatirlaticiAktif !== false &&
            uData.islemBildirimleriAktif !== false;

          if (token && puantajAktif) {
            await fcm.send({
              token,
              notification: {
                title: '⚠️ Eksik Puantaj & Rapor Hatırlatması',
                body: `${teamData.ad || 'Şantiye'} için bugünkü puantaj veya rapor henüz girilmedi.`,
              },
              data: {
                teamId: teamDoc.id,
                action: 'daily_report',
              },
              android: {
                notification: {
                  channelId: 'santiye_bildirim_kanali',
                  icon: 'notification_icon',
                  color: '#14B8A6',
                  priority: 'high',
                },
              },
            });
          }
        }
      } catch (err) {
        console.error(`onDailyPuantajReminder error (${teamDoc.id}):`, err);
      }
    }
  }
);

// ─── 3. HAFTALIK ÖZET (HER PAZARTESİ SABAH 09:00 TR) ─────────────────────────

exports.onWeeklySummary = onSchedule(
  {
    schedule: '0 9 * * 1', // Her Pazartesi 09:00 TR (Sabah 5 değil, iş başı saati)
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
            title: '📊 Haftalık Şantiye Durum Özeti',
            body: `Geçen hafta ${raporSayisi} rapor girildi. Haftalık analiz ekranını incelemek için dokunun!`,
          },
          data: {
            teamId: teamDoc.id,
            action: 'weekly_summary',
            islemTipi: 'HAFTALIK_OZET',
          },
          android: {
            notification: {
              channelId: 'santiye_bildirim_kanali',
              icon: 'notification_icon',
              color: '#14B8A6',
              priority: 'high',
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
    case 'ISCI_KART_ESLESMESI':
      return {
        title: '📋 İşçi Kartınız Eşleştirildi',
        body: `${username}, ${detaylar.isciAdi || 'işçi'} kartınızı hesabınızla eşleştirdi. Puantaj ve hakediş dökümünüz güncellendi.`,
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
        title: '🔑 Rol / Yetki Ataması',
        body: `${username}, ekibinizde ${detaylar.yeniRol === 'yonetici' ? 'Yönetici' : 'Puantör/Üye'} yetkisi tanımladı.`,
      };
    case 'EKIBE_KATILIM':
      return {
        title: '👷 Ekibe Yeni Katılım',
        body: `${username}, ${detaylar.ekipAdi ? detaylar.ekipAdi + ' ' : ''}ekibinize katıldı.`,
      };
    default:
      return {
        title: '🏗️ Şantiye Defteri',
        body: `${username} bir işlem gerçekleştirdi.`,
      };
  }
}
