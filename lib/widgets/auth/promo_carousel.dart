import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/auth/promo_slide.dart';
import 'package:seafoundry_app/widgets/ui.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  static const _autoAdvanceDuration = Duration(seconds: 5);
  static const _slides = [
    (
      title: 'Track coral restoration at scale',
      subtitle: 'Monitor holdings across nurseries and outplant sites with real-time data',
      icon: Icons.map_outlined,
      color: AppColors.primary,
    ),
    (
      title: 'Monitor field activities in real-time',
      subtitle: 'Log events, measurements, and observations as they happen',
      icon: Icons.event_outlined,
      color: AppColors.secondary,
    ),
    (
      title: 'Manage your organization\'s data',
      subtitle: 'Collaborate with your team and share impact with stakeholders',
      icon: Icons.analytics_outlined,
      color: AppColors.organizationColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceDuration, (_) {
      if (!mounted) return;

      final nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    // Reset auto-advance timer when user manually swipes
    _startAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return PromoSlide(
                  title: slide.title,
                  subtitle: slide.subtitle,
                  icon: slide.icon,
                  backgroundColor: slide.color,
                );
              },
            ),
          ),
          UI.spacingVerticalMd,
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? AppColors.primary
                : AppColors.divider,
          ),
        ),
      ),
    );
  }
}
