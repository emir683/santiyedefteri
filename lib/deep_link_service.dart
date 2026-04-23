import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'gunluk_rapor_ekrani.dart';
import 'join_team_page.dart';

class TeamInvitePayload {
  const TeamInvitePayload({
    required this.ekipAdi,
    this.ekipId,
    this.sifre,
  });

  final String ekipAdi;
  final String? ekipId;
  final String? sifre;
}

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<TeamInvitePayload?> _inviteController =
      StreamController<TeamInvitePayload?>.broadcast();

  StreamSubscription<Uri>? _linkSubscription;
  TeamInvitePayload? _pendingInvite;
  bool _pendingQuickReport = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  bool _isPresentingJoinPage = false;
  bool _isPresentingQuickReport = false;

  Stream<TeamInvitePayload?> get inviteStream => _inviteController.stream;

  TeamInvitePayload? get pendingInvite => _pendingInvite;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _processUri(initialUri);
      }
    } catch (_) {
      // Ignore initial deep-link failures.
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) async {
      await _processUri(uri);
    });
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _inviteController.close();
  }

  Future<void> _processUri(Uri uri) async {
    final bool isQuickReportLink =
        uri.scheme == 'santiyeapp' &&
        uri.host == 'widget' &&
        uri.path == '/quick-report';

    if (isQuickReportLink) {
      _pendingQuickReport = true;
      _openQuickReportIfPossible();
      return;
    }

    final bool isJoinLink =
        (uri.scheme == 'https' &&
            uri.host == 'emrcore.com' &&
            uri.path == '/katil') ||
        (uri.scheme == 'santiyeapp' && uri.host == 'katil');

    if (!isJoinLink) return;

    final String ekipAdi = uri.queryParameters['ad']?.trim() ?? '';
    final String ekipId =
        (uri.queryParameters['id'] ?? uri.queryParameters['ekipId'] ?? '')
            .trim();
    final String sifre = uri.queryParameters['sifre']?.trim() ?? '';

    if (ekipAdi.isEmpty || (ekipId.isEmpty && sifre.isEmpty)) return;

    _pendingInvite = TeamInvitePayload(
      ekipAdi: ekipAdi,
      ekipId: ekipId.isEmpty ? null : ekipId,
      sifre: sifre.isEmpty ? null : sifre,
    );
    _inviteController.add(_pendingInvite);
    _openJoinPageIfPossible();
  }

  void tryPresentPendingInvite() {
    _openJoinPageIfPossible();
    _openQuickReportIfPossible();
  }

  void _openJoinPageIfPossible() {
    final navigator = _navigatorKey?.currentState;
    final invite = _pendingInvite;
    final user = FirebaseAuth.instance.currentUser;

    if (navigator == null || invite == null || user == null) return;
    if (_isPresentingJoinPage) return;

    _isPresentingJoinPage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigatorKey?.currentState;
      final activeInvite = _pendingInvite;
      if (nav == null || activeInvite == null) {
        _isPresentingJoinPage = false;
        return;
      }

      nav
          .push(
            MaterialPageRoute(
              builder:
                  (_) => JoinTeamPage(
                    ekipAdi: activeInvite.ekipAdi,
                    ekipId: activeInvite.ekipId,
                    sifre: activeInvite.sifre,
                  ),
            ),
          )
          .whenComplete(() async {
            if (_isSameInvite(_pendingInvite, activeInvite)) {
              await clearInvite();
            }
            _isPresentingJoinPage = false;
          });
    });
  }

  void _openQuickReportIfPossible() {
    final navigator = _navigatorKey?.currentState;
    final user = FirebaseAuth.instance.currentUser;

    if (!_pendingQuickReport || navigator == null || user == null) return;
    if (_isPresentingQuickReport) return;

    _isPresentingQuickReport = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentQuickReport(user);
    });
  }

  Future<void> _presentQuickReport(User user) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final teamId = (snapshot.data()?['teamId'] as String?)?.trim();
      final nav = _navigatorKey?.currentState;

      if (nav == null || teamId == null || teamId.isEmpty) {
        return;
      }

      _pendingQuickReport = false;
      await nav.push(
        MaterialPageRoute(
          builder: (_) => GunlukRaporEkrani(teamId: teamId),
        ),
      );
    } finally {
      _isPresentingQuickReport = false;
    }
  }

  Future<TeamInvitePayload?> consumeInvite() async {
    final TeamInvitePayload? invite = _pendingInvite;
    if (invite == null) return null;

    _pendingInvite = null;
    _inviteController.add(null);
    return invite;
  }

  Future<void> clearInvite() async {
    _pendingInvite = null;
    _inviteController.add(null);
  }

  bool _isSameInvite(TeamInvitePayload? left, TeamInvitePayload? right) {
    if (left == null || right == null) return false;
    return left.ekipAdi == right.ekipAdi &&
        left.ekipId == right.ekipId &&
        left.sifre == right.sifre;
  }
}
