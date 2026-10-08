import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prana_health/core/database/local_storage_service.dart';
import 'package:prana_health/core/services/prana_health_controller.dart';
import 'package:prana_health/features/ai/mock_inference_service.dart';
import 'package:prana_health/features/ml/personal_model.dart';
import 'package:prana_health/features/ml/personalization_status.dart';
import 'package:prana_health/features/ml/personalized_inference_service.dart';
import 'package:prana_health/features/ml/vitals_sample_store.dart';
import 'package:prana_health/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline local storage
  final storageService = await LocalStorageService.init();
  final onboardingComplete = storageService.isOnboardingComplete();

  // On-device per-person ML pipeline. The store holds the individual's vitals
  // and the learned baseline model; the personalized service wraps the
  // population prior (MockInferenceService) and personalizes to this user,
  // resuming from whatever it learned in previous sessions. This is the only
  // wiring needed — the controller just sees an MLInferenceService.
  final vitalsStore = await VitalsSampleStore.open();
  final savedModel = await vitalsStore.loadModel();
  final personalModel = savedModel == null
      ? PersonalModel.fresh()
      : PersonalModel.fromSnapshot(savedModel);
  final mlService = PersonalizedInferenceService(
    MockInferenceService(), // population prior / cold-start fallback
    vitalsStore, // the individual's on-device vitals database
    personalModel, // the per-person baseline model (resumed if it exists)
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PranaHealthController(
            storage: storageService,
            customMlService: mlService,
          ),
        ),
        // The raw on-device vitals database, exposed read-only so the data
        // export screen can read and decode the recorded samples. A plain
        // Provider (not ListenableProvider) because the store is NOT a
        // Listenable; `.value` because main() owns its lifecycle.
        Provider<VitalsSampleStore>.value(value: vitalsStore),
        // Live personalization progress for the dashboard card. It is a
        // ValueListenable, so it must go through ListenableProvider — a plain
        // Provider rejects Listenables at runtime (it couldn't know to rebuild
        // on change). `.value` because the service owns the notifier's lifecycle
        // (disposed with the controller), so the provider must not dispose it.
        // The dashboard reads it once and listens via ValueListenableBuilder, so
        // this never rebuilds the widget tree on a new sample.
        ListenableProvider<ValueListenable<PersonalizationStatus>>.value(
          value: mlService.status,
        ),
      ],
      child: PranaApp(initialOnboardingComplete: onboardingComplete),
    ),
  );
}
