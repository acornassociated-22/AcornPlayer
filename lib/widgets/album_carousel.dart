import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../models/song.dart';
import 'vinyl_card.dart';

/// Swipeable cover flow: the centred card is full size with a bright halo, its
/// neighbours sit behind it, smaller and dimmer.
///
/// Dragging left or tapping the right side moves to the next track; dragging
/// right or tapping the left side moves to the previous one.
class AlbumCarousel extends StatefulWidget {
  const AlbumCarousel({
    super.key,
    required this.songs,
    required this.currentIndex,
    required this.onIndexChanged,
    this.height = 300,
    this.wide = false,
    this.isPlaying = false,
    this.progress = 0,
  });

  final List<Song> songs;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final double height;
  final bool wide;
  final bool isPlaying;

  /// 0–1 playback progress for the centred card's platter ring.
  final double progress;

  @override
  State<AlbumCarousel> createState() => _AlbumCarouselState();
}

class _AlbumCarouselState extends State<AlbumCarousel>
    with SingleTickerProviderStateMixin {
  static const _neighbours = 2;
  static const _flingVelocity = 320.0;

  static const _phoneCardFactor = 0.48;
  static const _phoneSlotFactor = 0.22;
  static const _wideCardFactor = 0.56;
  static const _wideSlotFactor = 0.28;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Animation<double>? _settleTween;

  late double _page = widget.currentIndex.toDouble();
  double _dragStartPage = 0;
  double _slotWidth = 1;
  double _cardLeft = 0;
  double _cardSize = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(() => _page = _settleTween?.value ?? _page);
    });
  }

  @override
  void didUpdateWidget(AlbumCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final songsChanged = !identical(widget.songs, oldWidget.songs);
    if (songsChanged) {
      _settle.stop();
      _page = widget.currentIndex.toDouble();
      return;
    }
    if (widget.currentIndex == oldWidget.currentIndex) return;
    if (_page.round() == widget.currentIndex) return;
    _moveTo(widget.currentIndex.toDouble());
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _moveTo(double target) {
    if ((target - _page).abs() > 1.5) {
      _settle.stop();
      setState(() => _page = target);
      return;
    }
    _settleTween = Tween<double>(begin: _page, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    _settle.forward(from: 0);
  }

  void handleDragStart(DragStartDetails details) {
    _settle.stop();
    _dragStartPage = _page;
  }

  void handleDragUpdate(DragUpdateDetails details) {
    final delta = (details.primaryDelta ?? 0) / _slotWidth;
    setState(() {
      _page = (_page - delta).clamp(0.0, (widget.songs.length - 1).toDouble());
    });
  }

  void handleDragEnd(DragEndDetails details) {
    final last = widget.songs.length - 1;
    if (last <= 0) return;
    final velocity = details.primaryVelocity ?? 0;
    final flung = velocity.abs() > _flingVelocity;
    var target = flung
        ? _dragStartPage.round() + (velocity < 0 ? 1 : -1)
        : _page.round();
    handleGoTo(_wrapIndex(target));
  }

  /// Left of the centre card is previous; right of it is next.
  void handleTapUp(TapUpDetails details) {
    final x = details.localPosition.dx;
    if (x < _cardLeft) {
      handleStep(-1);
    } else if (x > _cardLeft + _cardSize) {
      handleStep(1);
    }
  }

  /// Moves one track, wrapping at the ends.
  void handleStep(int delta) {
    if (widget.songs.length <= 1) return;
    handleGoTo(_wrapIndex(widget.currentIndex + delta));
  }

  /// Settles the coverflow and notifies the player.
  void handleGoTo(int target) {
    _moveTo(target.toDouble());
    if (target != widget.currentIndex) widget.onIndexChanged(target);
  }

  /// Wraps [index] around the queue.
  int _wrapIndex(int index) {
    final last = widget.songs.length - 1;
    if (last <= 0) return 0;
    if (index < 0) return last;
    if (index > last) return 0;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardFactor =
            widget.wide ? _wideCardFactor : _phoneCardFactor;
        final slotFactor = widget.wide ? _wideSlotFactor : _phoneSlotFactor;
        // Shadows and the neighbour scale stay inside the slider well.
        const shadowPad = 18.0;
        final maxHeight =
            (widget.height - shadowPad * 2).clamp(80.0, widget.height);
        final maxWidth = constraints.maxWidth * cardFactor;
        var cardHeight = maxHeight;
        var cardWidth = cardHeight * 0.72;
        if (cardWidth > maxWidth) {
          cardWidth = maxWidth;
          cardHeight = cardWidth / 0.72;
        }
        _cardSize = cardWidth;
        _slotWidth = widget.wide
            ? constraints.maxWidth * slotFactor
            : cardWidth * (slotFactor / cardFactor);
        final left = (constraints.maxWidth - cardWidth) / 2;
        _cardLeft = left;

        final indices = _visibleIndices()
          ..sort((a, b) => (_page - b).abs().compareTo((_page - a).abs()));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: handleDragStart,
          onHorizontalDragUpdate: handleDragUpdate,
          onHorizontalDragEnd: handleDragEnd,
          onTapUp: handleTapUp,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.center,
              children: [
                for (final index in indices)
                  _buildCard(index, cardWidth, cardHeight, left),
              ],
            ),
          ),
        );
      },
    );
  }

  List<int> _visibleIndices() {
    final centre = _page.round();
    return [
      for (var i = centre - _neighbours; i <= centre + _neighbours; i++)
        if (i >= 0 && i < widget.songs.length) i,
    ];
  }

  Widget _buildCard(
    int index,
    double cardWidth,
    double cardHeight,
    double left,
  ) {
    final offset = index - _page;
    final motion = _CardMotion.fromOffset(offset);
    final focused = motion.focus > 0.85;

    return Positioned(
      left: left + offset * _slotWidth,
      top: (widget.height - cardHeight) / 2,
      width: cardWidth,
      height: cardHeight,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(motion.rotateY),
        child: Transform.scale(
          scale: motion.scale,
          child: Opacity(
            opacity: motion.opacity,
            child: VinylCard(
              song: widget.songs[index],
              isActive: focused,
              isPlaying: focused && widget.isPlaying,
              progress: focused ? widget.progress : 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Interpolated pose for one cover at [offset] slots from centre.
class _CardMotion {
  const _CardMotion({
    required this.scale,
    required this.opacity,
    required this.rotateY,
    required this.focus,
  });

  factory _CardMotion.fromOffset(double offset) {
    final distance = offset.abs();
    final t = Curves.easeOutCubic.transform(distance.clamp(0.0, 1.0));

    return _CardMotion(
      scale: lerpDouble(1, 0.72, t)!,
      opacity: lerpDouble(1, 0.35, t)!,
      rotateY: lerpDouble(0, -offset.sign * 0.18, t)!,
      focus: (1 - distance.clamp(0.0, 1.0)),
    );
  }

  final double scale;
  final double opacity;
  final double rotateY;
  final double focus;
}
