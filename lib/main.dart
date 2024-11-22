import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock<IconData>(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (icon) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[icon.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(icon, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  final List<T> items;

  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

class _DockState<T extends Object> extends State<Dock<T>> {
  late final List<T> _items = widget.items.toList();

  T? _draggingItem;

  Offset _dragOffset = Offset.zero;

  Timer? _outsideTimer;

  final Duration _holdDuration = const Duration(milliseconds: 500);

  bool _shouldRemove = false;

  Size? _dockSize;

  final StreamController<Offset> _dragPositionController = StreamController<Offset>.broadcast();

  @override
  void dispose() {
    _dragPositionController.close(); // Dispose of the StreamController.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Capture the size of the Dock container
        _dockSize = constraints.biggest;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black12,
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int index = 0; index < _items.length; index++)
                DragTarget<T>(
                  onAcceptWithDetails: (details) {
                    setState(() {
                      final receivedItem = details.data;
                      final oldIndex = _items.indexOf(receivedItem);
                      final item = _items.removeAt(oldIndex);
                      _items.insert(index, item);
                      _draggingItem = null;
                      _dragOffset = Offset.zero;
                      _outsideTimer?.cancel();
                      _shouldRemove = false; // Cancel removal if item is put back.
                    });
                  },
                  onWillAcceptWithDetails: (details) => details.data != _items[index],
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.all(8),
                      child: Draggable<T>(
                        data: _items[index],
                        feedback: Transform.translate(
                          offset: _dragOffset,
                          child: widget.builder(_items[index]),
                        ),
                        childWhenDragging: _draggingItem == _items[index] ? Opacity(opacity: 0.0, child: widget.builder(_items[index])) : widget.builder(_items[index]),
                        onDragUpdate: (details) {
                          setState(() {
                            _dragOffset = _constrainOffset(details.localPosition);

                            // Broadcast the drag position.
                            _dragPositionController.add(details.globalPosition);

                            // Check if dragged outside boundaries
                            if (details.localPosition.dy < -50 || details.localPosition.dy > 100) {
                              _startOutsideTimer();
                            } else {
                              // Cancel timer if returned within boundaries
                              _outsideTimer?.cancel();
                            }
                          });
                        },
                        onDragStarted: () {
                          setState(() {
                            _draggingItem = _items[index];
                            _shouldRemove = false; // Reset the remove flag when starting drag
                          });
                        },
                        onDragEnd: (_) {
                          setState(() {
                            if (_shouldRemove) {
                              _items.removeAt(index); // Remove item if held outside for too long
                            }
                            _draggingItem = null;
                            _dragOffset = Offset.zero;
                            _outsideTimer?.cancel();
                          });
                        },
                        child: widget.builder(_items[index]),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Offset _constrainOffset(Offset offset) {
    final maxX = _dockSize!.width - 48; // Constrain to the width of the Dock
    final maxY = _dockSize!.height - 48; // Constrain to the height of the Dock

    final clampedX = offset.dx.clamp(0.0, maxX);
    final clampedY = offset.dy.clamp(0.0, maxY);

    return Offset(clampedX, clampedY);
  }

  void _startOutsideTimer() {
    _outsideTimer?.cancel(); // Cancel any existing timer
    _outsideTimer = Timer(_holdDuration, () {
      setState(() {
        _shouldRemove = true; // Mark the item for removal if held for the duration
      });
    });
  }
}
