import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One promo slide: artwork on the right, text on the left. Tapping opens
/// the products of [categorySlug], or just shows [info] when there is none.
class PromoSlide {
  final String asset;
  final String tag;
  final String title;
  final String subtitle;
  final String? categorySlug;
  final String? info;

  const PromoSlide({
    required this.asset,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.categorySlug,
    this.info,
  });

  static const all = [
    PromoSlide(
      asset: 'assets/banner/banner_figures.webp',
      tag: 'NEW IN',
      title: 'New scale figures',
      subtitle: 'Premium 1/7 and 1/8 figures',
      categorySlug: 'scale-figures',
    ),
    PromoSlide(
      asset: 'assets/banner/banner_tcg.webp',
      tag: 'RESTOCK',
      title: 'Booster boxes are back',
      subtitle: 'One Piece, Pokemon and more',
      categorySlug: 'tcg-boosters',
    ),
    PromoSlide(
      asset: 'assets/banner/banner_plush.webp',
      tag: 'CUTE DEALS',
      title: 'Soft plush friends',
      subtitle: 'Plushies, keychains and stands',
      categorySlug: 'plush-merch',
    ),
    PromoSlide(
      asset: 'assets/banner/banner_kits.webp',
      tag: 'BUILD IT',
      title: 'Model kits for builders',
      subtitle: r'No glue needed, from $19',
      categorySlug: 'model-kits',
    ),
    PromoSlide(
      asset: 'assets/banner/banner_delivery.webp',
      tag: 'FREE DELIVERY',
      title: r'Free delivery over $50',
      subtitle: 'Anywhere in Phnom Penh',
      info: r'Orders of $50 or more ship free in Phnom Penh. Smaller orders ship for $2.',
    ),
  ];
}

/// Auto-playing banner slider on Home (carousel_slider), with dots that
/// can be tapped. Auto-play is off when "reduce motion" is on.
class PromoCarousel extends StatefulWidget {
  final List<PromoSlide> slides;
  final ValueChanged<PromoSlide> onTap;

  const PromoCarousel({super.key, this.slides = PromoSlide.all, required this.onTap});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = CarouselSliderController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final slides = widget.slides;

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          itemCount: slides.length,
          options: CarouselOptions(
            aspectRatio: 3, // the artwork is 1500 x 500
            viewportFraction: 1,
            autoPlay: !reduceMotion && slides.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 600),
            autoPlayCurve: Curves.easeOutCubic,
            pauseAutoPlayOnTouch: true,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
          itemBuilder: (_, i, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _Slide(slide: slides[i], onTap: () => widget.onTap(slides[i])),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                Semantics(
                  button: true,
                  selected: i == _index,
                  label: 'Slide ${i + 1} of ${slides.length}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _controller.animateToPage(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      child: AnimatedContainer(
                        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                        width: i == _index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index ? scheme.primary : scheme.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  final PromoSlide slide;
  final VoidCallback onTap;

  const _Slide({required this.slide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      label: '${slide.title}. ${slide.subtitle}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (_, c) => Image.asset(
                slide.asset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                cacheWidth: (c.maxWidth * dpr).round(),
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.cardStart, AppTheme.cardEnd]),
                  ),
                ),
              ),
            ),
            // Darker blue behind the text so small white text stays readable
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.cardStart.withValues(alpha: 0.92),
                    AppTheme.cardStart.withValues(alpha: 0.70),
                    AppTheme.cardStart.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.42, 0.62],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: Key('promo_${slide.asset.split('/').last.split('.').first}'),
                onTap: onTap,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            slide.tag,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          slide.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.2, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          slide.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
