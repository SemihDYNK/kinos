// Native rendering probe: run with `fvm flutter run -d linux --profile
// -t tool/diagnostics/glass_scroll_probe.dart`. No accounts or network calls.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

void main() => runApp(MaterialApp(
      theme: buildAppTheme(),
      home: const _GlassScrollProbe(),
    ));

class _GlassScrollProbe extends StatefulWidget {
  const _GlassScrollProbe();
  @override
  State<_GlassScrollProbe> createState() => _GlassScrollProbeState();
}

class _GlassScrollProbeState extends State<_GlassScrollProbe> {
  final _scroll = ScrollController();
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
              (_frame * 18.0).clamp(0, _scroll.position.maxScrollExtent));
        }
        setState(() => _frame++);
        if (_frame == 600) exit(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          GridView.builder(
            controller: _scroll,
            itemCount: 1000,
            padding: const EdgeInsets.fromLTRB(100, 120, 30, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisExtent: 240,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20),
            itemBuilder: (context, index) => PosterHoverMotion(
              active: index == ((_frame * 18 + 240) / 260).floor() * 8 + 3,
              builder: (context, reveal) => Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.primaries[index % Colors.primaries.length],
                        AppColors.background,
                      ]),
                    ),
                  ),
                  Text('Poster $index'),
                  Center(
                    child: Opacity(
                      opacity: reveal,
                      child: const FrostedSurface(
                        child: SizedBox.square(
                            dimension: 50, child: Icon(Icons.play_arrow)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 40,
            left: 350,
            right: 350,
            child: FrostedSurface(
              child: SizedBox(
                  height: 60, child: Center(child: Text('TOPBAR FIXED'))),
            ),
          ),
          const Positioned(
            top: 180,
            left: 12,
            bottom: 180,
            child: FrostedSurface(
              child: SizedBox(width: 68, child: Center(child: Text('K'))),
            ),
          ),
        ]),
      );
}
