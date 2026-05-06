import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobBottomBanner extends StatefulWidget {
  const AdMobBottomBanner({super.key});

  @override
  State<AdMobBottomBanner> createState() => _AdMobBottomBannerState();
}

class _AdMobBottomBannerState extends State<AdMobBottomBanner> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoading = false;
  int? _lastAdWidth;
  Orientation? _lastOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdIfNeeded();
  }

  Future<void> _loadAdIfNeeded() async {
    final mediaQuery = MediaQuery.of(context);
    final adWidth = mediaQuery.size.width.truncate();
    final orientation = mediaQuery.orientation;

    if (adWidth <= 0) return;
    if (_isLoading) return;
    if (_bannerAd != null && _lastAdWidth == adWidth && _lastOrientation == orientation) {
      return;
    }

    _isLoading = true;
    _lastAdWidth = adWidth;
    _lastOrientation = orientation;

    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth);

    if (!mounted) {
      _isLoading = false;
      return;
    }

    if (adSize == null) {
      _disposeBanner();
      setState(() {
        _adSize = null;
        _isLoaded = false;
      });
      _isLoading = false;
      return;
    }

    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = adSize;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;

          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoaded = false;
          });
        },
      ),
    );

    _disposeBanner();
    _bannerAd = banner;
    _isLoaded = false;
    _adSize = adSize;

    await banner.load();
    _isLoading = false;
  }

  String get _bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-2562096237368251/8311821628';
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-2562096237368251/4348525887';
    }

    return '';
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: _adSize!.width.toDouble(),
          height: _adSize!.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
