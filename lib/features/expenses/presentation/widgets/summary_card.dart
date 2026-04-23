import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final double total;

  const SummaryCard({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Current Month Total', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
