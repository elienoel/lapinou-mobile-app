import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'rabbit_avatar.dart';

class GenealogyTreeWidget extends StatelessWidget {
  final Rabbit rabbit;
  final RabbitProvider provider;
  final Function(Rabbit)? onSelectRabbit;

  const GenealogyTreeWidget({
    super.key,
    required this.rabbit,
    required this.provider,
    this.onSelectRabbit,
  });

  @override
  Widget build(BuildContext context) {
    final father = provider.getRabbitById(rabbit.sireId);
    final mother = provider.getRabbitById(rabbit.damId);

    final paternalGrandFather =
        father != null ? provider.getRabbitById(father.sireId) : null;
    final paternalGrandMother =
        father != null ? provider.getRabbitById(father.damId) : null;

    final maternalGrandFather =
        mother != null ? provider.getRabbitById(mother.sireId) : null;
    final maternalGrandMother =
        mother != null ? provider.getRabbitById(mother.damId) : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Level 0: Subject Rabbit
            _buildSubjectCard(rabbit),

            const SizedBox(height: 12),
            _buildConnector(),
            const SizedBox(height: 12),

            // Level 1: Parents
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildParentBranch(
                  title: 'PÈRE ♂',
                  parent: father,
                  grandFather: paternalGrandFather,
                  grandMother: paternalGrandMother,
                  color: AppColors.maleBlue,
                ),
                const SizedBox(width: 24),
                _buildParentBranch(
                  title: 'MÈRE ♀',
                  parent: mother,
                  grandFather: maternalGrandFather,
                  grandMother: maternalGrandMother,
                  color: AppColors.femalePink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Rabbit r) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          RabbitAvatar(rabbit: r, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.genderSymbol,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.breed} • ${r.tagNumber}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentBranch({
    required String title,
    required Rabbit? parent,
    required Rabbit? grandFather,
    required Rabbit? grandMother,
    required Color color,
  }) {
    return Column(
      children: [
        // Parent Card
        _buildNodeCard(roleLabel: title, rabbit: parent, accentColor: color),
        const SizedBox(height: 10),
        _buildConnector(),
        const SizedBox(height: 10),

        // Grandparents
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNodeCard(
              roleLabel: 'G-Père ♂',
              rabbit: grandFather,
              accentColor: AppColors.maleBlue,
              isSmall: true,
            ),
            const SizedBox(width: 10),
            _buildNodeCard(
              roleLabel: 'G-Mère ♀',
              rabbit: grandMother,
              accentColor: AppColors.femalePink,
              isSmall: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNodeCard({
    required String roleLabel,
    required Rabbit? rabbit,
    required Color accentColor,
    bool isSmall = false,
  }) {
    final width = isSmall ? 130.0 : 160.0;

    if (rabbit == null) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roleLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Non renseigné',
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onSelectRabbit != null ? () => onSelectRabbit!(rabbit) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          vertical: isSmall ? 8 : 10,
          horizontal: isSmall ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: accentColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            RabbitAvatar(
              rabbit: rabbit,
              size: isSmall ? 28 : 34,
              showGenderBadge: false,
            ),
            const SizedBox(height: 4),
            Text(
              rabbit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmall ? 12 : 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              rabbit.tagNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            if (!isSmall) ...[
              const SizedBox(height: 2),
              Text(
                rabbit.breed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Container(width: 2, height: 14, color: Colors.grey.shade300);
  }
}
