import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner + interstitial + rewarded ads, using the app's real
/// AdMob ad units (the matching App ID comes from the ADMOB_APP_ID CI
/// secret). Don't tap ads on your own test devices — register them as
/// test devices in AdMob instead.
///
/// `google_mobile_ads` only supports Android/iOS, so every entry point
/// here is a no-op on web/desktop, keeping `flutter run -d chrome`/
/// web-server usable for previewing gameplay without a phone.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String bannerAdUnitId = 'ca-app-pub-9078637596840810/4343210239';
  static const String interstitialAdUnitId = 'ca-app-pub-9078637596840810/4974473465';

  /// Rewarded: "x2 coins" on level complete.
  static const String rewardedAdUnitId = 'ca-app-pub-9078637596840810/2348310122';

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;

  /// Whether a rewarded ad is loaded and can be offered right now — the
  /// x2 button only appears while this is true.
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadRewarded() {
    if (kIsWeb || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (_) {
          _rewardedLoading = false;
          rewardedReady.value = false;
          // No fill is common; try again a little later.
          Timer(const Duration(seconds: 45), _loadRewarded);
        },
      ),
    );
  }

  /// Plays a rewarded ad. [onReward] runs only if the player watched it
  /// through; [onDone] always runs once the ad is gone (or couldn't show).
  void showRewarded({required VoidCallback onReward, required VoidCallback onDone}) {
    final ad = _rewarded;
    if (ad == null) {
      onDone();
      _loadRewarded();
      return;
    }
    _rewarded = null;
    rewardedReady.value = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
        onDone();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
  }

  BannerAd? createBannerAd({required void Function() onLoaded}) {
    if (kIsWeb) return null;
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  void _loadInterstitial() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Shows an interstitial at a natural break point (level complete or
  /// game over), matching the original's "ad after each level" pattern —
  /// unlike the every-other-game throttle used elsewhere in this series,
  /// since here every level end is itself already a meaningful pause.
  void maybeShowInterstitial() {
    if (kIsWeb) return;
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    _interstitialAd = null;
    ad.show();
  }
}
