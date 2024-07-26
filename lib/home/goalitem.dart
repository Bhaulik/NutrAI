import 'package:flutter/material.dart';

class GoalItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const GoalItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected ? BorderSide(color: Colors.green, width: 2) : BorderSide.none,
        ),
        elevation: selected ? 4 : 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 24),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              if (selected)
                Icon(Icons.check, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}
