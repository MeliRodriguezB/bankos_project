import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusUpper = status.toUpperCase();
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (statusUpper) {
      case 'ACTIVE':
        bgColor = const Color(0xFFDCFCE7); // Verde pastel suave
        textColor = const Color(0xFF166534); // Verde oscuro accesible
        label = 'Activa';
        break;
      case 'INACTIVE':
        bgColor = const Color(0xFFF1F5F9); // Gris suave
        textColor = const Color(0xFF475569); // Gris medio
        label = 'Inactiva';
        break;
      case 'BLOCKED':
        bgColor = const Color(0xFFFEE2E2); // Rojo suave
        textColor = const Color(0xFF991B1B); // Rojo oscuro
        label = 'Bloqueada';
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
