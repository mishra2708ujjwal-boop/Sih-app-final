import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/swipe_to_confirm.dart';
import 'emergency_service.dart';
import 'emergency_dispatcher.dart';

/// Secondary text on the emergency screen's near-black background. Warm rather
/// than slate, so it belongs to the same palette as the rest of the app.
const Color _dimOnDark = Color(0xFFE3D8D4);

/// Emergency screen — reached from the centre SOS button (which navigates here
/// rather than dispatching, so a mis-tap costs nothing) and surfaced
/// automatically by the shell when a fall starts the countdown.
///
/// On a fall, after the cancel countdown, PRANA dispatches automatically: it
/// captures the exact GPS location, sends an SMS to the primary emergency
/// contact, and places a phone call to them — via the native prana/emergency
/// channel. This screen shows the live outcome of each of those, and still
/// writes the message out with a Copy action as a fallback for when the OS
/// blocks auto-send (e.g. MIUI without the extra permissions).
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final emergency = controller.emergencyService;
    final state = emergency.currentState;

    final isAlarming =
        state == EmergencyState.countdown || state == EmergencyState.sosSent;

    // Calm, light shell while nothing is happening; the alarm states take over
    // the whole screen in near-black red so they can't be mistaken for anything
    // else, and so the screen is readable in bright sun at full brightness.
    if (!isAlarming) return const _IdleView();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1013),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          state == EmergencyState.countdown ? 'Countdown' : 'SOS raised',
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: state == EmergencyState.countdown
            ? _CountdownView(emergency: emergency)
            : const _RaisedView(),
      ),
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────
/// What is being watched, who would be told, and what PRANA will and will not
/// do — all stated before the user commits to anything.
class _IdleView extends StatefulWidget {
  const _IdleView();

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  @override
  void initState() {
    super.initState();
    // Ask for SMS / phone / location up-front, so a real fall is never the
    // first time the OS prompts — the grants must already be in place for the
    // automatic dispatch to actually go out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PranaHealthController>().ensureEmergencyPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final emergency = controller.emergencyService;
    final profile = controller.userProfile;
    final contacts = profile.emergencyContacts;
    final watching = controller.hasLiveData;
    final lastFall = controller.lastFallDetectedAt;
    var order = 0;

    return PranaScaffold(
      title: 'Emergency',
      subtitle: 'Fall watch and SOS',
      tint: AppColors.riskCritical,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          // ── Is the fall watch actually running? ──────────────────────────────
          FadeSlideIn(
            index: order++,
            child: _WatchCard(watching: watching, lastFall: lastFall),
          ),
          AppSpacing.gapSm,

          // ── Who would be told ───────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: 'Who to contact',
              subtitle: contacts.isEmpty
                  ? 'Nobody saved yet'
                  : '${contacts.length} saved on this phone',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: contacts.isEmpty
                ? const AppCard(
                    child: EmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      iconColor: AppColors.riskCritical,
                      title: 'No emergency contact',
                      subtitle:
                          'Open the Profile tab to add one. An SOS still works '
                          'without it — it just has nobody to name.',
                      compact: true,
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < contacts.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.borderLight,
                            ),
                          _ContactRow(contact: contacts[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          AppSpacing.gapSm,

          // ── The honest description of what happens ──────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'What an SOS does',
              subtitle: 'Read this before you need it',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _Step(
                    number: 1,
                    title:
                        '${AppConstants.sosCountdownSeconds}-second countdown',
                    body: 'A detected fall starts this automatically. You can '
                        'cancel any time before it reaches zero — nothing is '
                        'sent until then.',
                  ),
                  AppSpacing.gapSm,
                  _Step(
                    number: 2,
                    title: 'PRANA texts your primary contact',
                    body: 'At zero, an SMS goes out automatically with your '
                        'exact location (a Google Maps link), your details, '
                        'medical notes and current vitals.',
                  ),
                  AppSpacing.gapSm,
                  _Step(
                    number: 3,
                    title: '…and calls them',
                    body: 'PRANA then places a phone call to the same contact '
                        'so they can respond straight away.',
                  ),
                ],
              ),
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Auto-dispatch needs SMS, phone and location permission. On '
                'Xiaomi/MIUI phones you may also have to enable Autostart and '
                'allow “send SMS”/“make calls” for PRANA in system settings, '
                'or the text and call are silently blocked.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          AppSpacing.gapMd,

          // ── The action ──────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SwipeToConfirm(
              label: 'Swipe to start SOS countdown',
              requireDrag: true,
              background: AppColors.riskCritical,
              handleIcon: Icons.sos_rounded,
              onConfirm: emergency.triggerManualSos,
            ),
          ),
          AppSpacing.gapXs,
          FadeSlideIn(
            index: order++,
            child: Text(
              'Swipe, so a phone in your pocket cannot do this by itself.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fall-watch status. Fall detection reads the band's accelerometer, so with no
/// band streaming there is nothing watching — and the card says so plainly
/// instead of showing a reassuring green light over a dead sensor.
class _WatchCard extends StatelessWidget {
  final bool watching;
  final DateTime? lastFall;

  const _WatchCard({required this.watching, required this.lastFall});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      showBorder: false,
      radius: AppRadius.xl,
      gradient: const LinearGradient(
        colors: AppColors.gradientDark,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: watching
                    ? Icons.sensors_rounded
                    : Icons.sensors_off_rounded,
                color: watching ? AppColors.accent : Colors.white70,
                background: Colors.white.withValues(alpha: 0.10),
                size: 38,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Fall watch',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
              ),
              StatusPill(
                label: watching ? 'Watching' : 'Not watching',
                color: watching ? AppColors.accent : Colors.white70,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                dense: true,
                showDot: true,
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            watching
                ? 'Your band is streaming motion. PRANA is checking every '
                    'reading for the impact-then-stillness pattern of a fall.'
                : 'Fall detection reads your band\'s motion sensor. With no '
                    'band connected there is nothing to watch — connect it to '
                    'turn the watch back on.',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          if (lastFall != null) ...[
            AppSpacing.gapSm,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.riskCritical.withValues(alpha: 0.20),
                borderRadius: AppRadius.brSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: Color(0xFFFCA5A5),
                  ),
                  AppSpacing.hGapXs,
                  Expanded(
                    child: Text(
                      'Last possible fall ${Fmt.ago(lastFall!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: const Color(0xFFFCA5A5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One saved contact, with a copy action — the only way this app can move a
/// phone number towards a dialler.
class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;

  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return InfoRow(
      icon: contact.isPrimary
          ? Icons.star_rounded
          : Icons.person_outline_rounded,
      iconColor:
          contact.isPrimary ? AppColors.riskCritical : AppColors.textSecondary,
      title: contact.isPrimary ? '${contact.name} · Primary' : contact.name,
      subtitle: '${contact.relation} · ${contact.phone}',
      trailing: CircleIconButton(
        icon: Icons.copy_rounded,
        size: 34,
        tooltip: 'Copy number',
        onTap: () => _copy(context, contact.phone, 'Number copied.'),
      ),
    );
  }
}

// ── Countdown ─────────────────────────────────────────────────────────────────
/// Cancel is the prominent action here on purpose: the countdown fires on its
/// own, so the affirmative choice needs no emphasis, and most countdowns a
/// conscious person sees are false positives they want to dismiss fast.
class _CountdownView extends StatelessWidget {
  final EmergencyService emergency;

  const _CountdownView({required this.emergency});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.60,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: StreamBuilder<int>(
                stream: emergency.countdownStream,
                initialData: emergency.countdownRemaining,
                builder: (context, snapshot) {
                  const total = AppConstants.sosCountdownSeconds;
                  final remaining = snapshot.data ?? total;
                  return _CountdownRing(
                    progress: total == 0 ? 0 : remaining / total,
                    remaining: remaining,
                  );
                },
              ),
            ),
            AppSpacing.gapLg,
            Text(
              'Possible fall detected',
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            AppSpacing.gapXs,
            Text(
              'Your band recorded an impact and little movement since. '
              'At zero, PRANA texts and calls your primary contact with your '
              'location.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: _dimOnDark,
              ),
            ),
            AppSpacing.gapXl,
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1013),
                ),
                icon: const Icon(Icons.check_rounded, size: 22),
                label: const Text(
                  "I'm OK — cancel",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: emergency.cancelEmergency,
              ),
            ),
            AppSpacing.gapSm,
            SizedBox(
              height: 54,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFFFCA5A5),
                    width: 1.6,
                  ),
                  foregroundColor: const Color(0xFFFCA5A5),
                ),
                onPressed: emergency.triggerManualSos,
                child: const Text(
                  'Skip the wait — raise it now',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Raised ────────────────────────────────────────────────────────────────────
/// The alert exists on this phone and the message is written. Sending it is a
/// human step, and this screen makes that the obvious next thing to do rather
/// than implying it already happened.
class _RaisedView extends StatelessWidget {
  const _RaisedView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final emergency = controller.emergencyService;
    final profile = controller.userProfile;
    final contacts = profile.emergencyContacts;
    // May legitimately be empty — a fresh install has nobody saved yet.
    final EmergencyContact? contact = contacts.isEmpty
        ? null
        : contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first);

    final message = _alertText(controller);

    // Live outcome of the automatic dispatch.
    final inProgress = emergency.dispatchInProgress;
    final smsSent = emergency.smsSent == true;
    final callStatus = emergency.callStatus;
    final calledOk = callStatus == 'called' || callStatus == 'dialer';
    final hasLocation = emergency.dispatchedMapsLink != null;
    final dispatched = !inProgress && (smsSent || calledOk);

    final title = inProgress
        ? 'Sending emergency alert…'
        : dispatched
            ? 'Emergency alert sent'
            : 'SOS raised on this phone';

    final subtitle = inProgress
        ? (contact == null
            ? 'Contacting your emergency contact…'
            : 'Alerting ${contact.name} with your location…')
        : contact == null
            ? 'No emergency contact is saved. The message below is ready — '
                'read it out or copy it.'
            : dispatched
                ? '${contact.name} has been texted and called with your '
                    'location. If it did not reach them, copy the message below.'
                : 'PRANA could not send automatically — copy the message below '
                    'and send it to ${contact.name}.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.riskCritical.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.riskCritical.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                size: 44,
                color: AppColors.riskCritical,
              ),
            ),
          ),
          AppSpacing.gapMd,
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppSpacing.gapXs,
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: _dimOnDark,
            ),
          ),
          AppSpacing.gapLg,

          // ── What was dispatched ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1E),
              borderRadius: AppRadius.brLg,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                _OutcomeRow(
                  icon: Icons.sms_rounded,
                  label: 'Text message',
                  value: inProgress
                      ? 'Sending…'
                      : smsSent
                          ? 'Sent'
                          : 'Not sent',
                  good: smsSent,
                  pending: inProgress,
                ),
                const Divider(height: 14, color: Colors.white12),
                _OutcomeRow(
                  icon: Icons.call_rounded,
                  label: 'Phone call',
                  value: inProgress
                      ? 'Waiting…'
                      : switch (callStatus) {
                          'called' => 'Call placed',
                          'dialer' => 'Dialler opened',
                          'skipped' => 'No contact saved',
                          _ => 'Failed',
                        },
                  good: calledOk,
                  pending: inProgress,
                ),
                const Divider(height: 14, color: Colors.white12),
                _OutcomeRow(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: (inProgress && !hasLocation)
                      ? 'Locating…'
                      : hasLocation
                          ? 'Included'
                          : 'Not available',
                  good: hasLocation,
                  pending: inProgress && !hasLocation,
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          // ── The message, verbatim and selectable ────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1E),
              borderRadius: AppRadius.brLg,
              border: Border.all(
                color: AppColors.riskCritical.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: Color(0xFFFCA5A5),
                    ),
                    AppSpacing.hGapXs,
                    Expanded(
                      child: Text(
                        'ALERT MESSAGE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelCaps.copyWith(
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                    ),
                    if (emergency.dispatchedTimestamp != null)
                      Text(
                        Fmt.clock(emergency.dispatchedTimestamp!),
                        style: AppTypography.bodySmall.copyWith(
                          color: _dimOnDark,
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapSm,
                SelectableText(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,

          // ── Real, working actions ──────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1013),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 20),
              label: const Text(
                'Copy the alert message',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => _copy(
                context,
                message,
                'Alert copied. Paste it into a message.',
              ),
            ),
          ),
          if (contact != null) ...[
            AppSpacing.gapSm,
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38, width: 1.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: Text(
                  'Copy ${contact.name}\'s number',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _copy(
                  context,
                  contact.phone,
                  'Number copied. Open your dialler to call.',
                ),
              ),
            ),
          ],
          AppSpacing.gapMd,
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _dimOnDark,
              ),
              onPressed: emergency.resolveEmergency,
              child: const Text('Mark as resolved'),
            ),
          ),
        ],
      ),
    );
  }

  /// The message a responder needs. Delegates to [buildEmergencyMessage] so the
  /// text shown here is byte-for-byte the SMS the controller actually sends.
  ///
  /// Vitals are labelled "right now" rather than "at the fall" because the
  /// service does not snapshot them at dispatch — and a live reading is the
  /// more useful number to read down a phone anyway.
  static String _alertText(PranaHealthController controller) {
    final emergency = controller.emergencyService;
    final gps = emergency.dispatchedGpsLocation;
    // Ignore transient placeholders/legacy "unavailable" strings for the body.
    final gpsText = (gps != null &&
            gps != 'Locating…' &&
            !gps.toLowerCase().contains('unavailable'))
        ? gps
        : null;
    return buildEmergencyMessage(
      profile: controller.userProfile,
      health: controller.currentHealth,
      risk: controller.currentRisk,
      hasLiveData: controller.hasLiveData,
      raisedAt: emergency.dispatchedTimestamp ?? DateTime.now(),
      gpsText: gpsText,
      mapsLink: emergency.dispatchedMapsLink,
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
/// Copy to clipboard and say so. Used for both the message and phone numbers —
/// the clipboard is the one hand-off that needs no plugin and no network.
void _copy(BuildContext context, String text, String confirmation) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.mediumImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(confirmation)));
}

/// One line in the "what was dispatched" card on the raised screen: an SMS /
/// call / location leg with a green tick, a red cross, or a pending hourglass.
class _OutcomeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool good;
  final bool pending;

  const _OutcomeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.good,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color valueColor = pending
        ? _dimOnDark
        : good
            ? const Color(0xFF86EFAC)
            : const Color(0xFFFCA5A5);
    final IconData statusIcon = pending
        ? Icons.hourglass_top_rounded
        : good
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.hGapXs,
        Icon(statusIcon, size: 16, color: valueColor),
      ],
    );
  }
}

/// A numbered step in the "what an SOS does" explainer.
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _Step({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.riskCritical;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.riskCriticalBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Countdown ring ────────────────────────────────────────────────────────────
/// A circular progress arc around the remaining seconds, so the time left is
/// legible at a glance without reading the numeral.
class _CountdownRing extends StatelessWidget {
  final double progress; // 0.0 (done) → 1.0 (full)
  final int remaining;

  const _CountdownRing({required this.progress, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(132, 132),
              painter: _ArcPainter(progress: progress),
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: AppColors.riskCritical.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.riskCritical, width: 2),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$remaining',
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 44,
                      height: 1.05,
                      color: AppColors.riskCritical,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    if (radius <= 0) return;
    const startAngle = -pi / 2;
    const fullSweep = 2 * pi;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      Paint()
        ..color = AppColors.riskCritical.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Active progress arc — sweeps clockwise.
    final sweep = fullSweep * progress.clamp(0.0, 1.0);
    if (sweep > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = AppColors.riskCritical
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}
