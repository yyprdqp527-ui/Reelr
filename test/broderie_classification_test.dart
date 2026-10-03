import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

/// Descriptions réelles de pins Pinterest d'un tableau point de croix
/// (oct. 2026) : avant cat_broderie, elles s'éparpillaient entre DIY,
/// Tricot, Crochet et Art.
void main() {
  group('Broderie : la couche locale suffit', () {
    const cases = [
      'A pixel art design featuring a stylized character with a pink and white color scheme. Cross-stitch, Cross stitch patterns, Cross stitching',
      'Two pixel art dolls, each with distinct colors and patterns. Hama beads, Perler beads, Mini cross stitch',
      'A collection of pixelated illustrations of various fruits and vegetables arranged in two rows. Cute cross stitch ideas, Cross stitch motifs',
      'A pixel art design of an acorn on a grid. A cross stitch, Cross-stitch, Counted cross stitch',
      'Create a beautiful bracelet with this alpha friendship pattern #146576. Perfect for DIY and craft enthusiasts. Get inspired by this unique stitch pattern. Cross stitch patterns, Pixel art pattern, Cross stitch designs',
      'Get creative with this cross stitch pattern featuring a vibrant red and green pepper. Perfect for adding a touch of color to your home decor or gifting to a fellow crafter. | Pixeles, Hama, Bordados en punto cruz',
      'Get this adorable watermelon cross stitch pattern for free. Download the PDF and start stitching today! Watermelon slice cross stitch, Crossstitch, Cross stitch designs',
      'Simple lemon cross stitch pattern in pixel style. This easy embroidery design is perfect for beginners and small handmade projects.',
      'Create your own adorable cross stitch ladybug with this pattern in pink and black. Perfect for adding a touch of whimsy to your DIY projects. Cross-stitch, Cross stitch designs, Cross stitching',
      'Grille point de croix gratuite : coquelicots',
      'Tuto broderie pour débutantes',
    ];
    for (final t in cases) {
      test(t.length > 50 ? t.substring(0, 50) : t, () {
        expect(CategoryClassifier.detectStrongMatch(t), 'Broderie', reason: t);
      });
    }
  });

  group('Broderie : pas de faux positifs', () {
    test('Lilo & Stitch', () {
      expect(CategoryClassifier.detectStrongMatch('Lilo & Stitch : les meilleures scènes'),
          isNot('Broderie'));
    });
    test('broder une histoire', () {
      expect(CategoryClassifier.detectStrongMatch('Il brode toujours autour de ses histoires'),
          isNot('Broderie'));
    });
  });

  group('Couture : non-régression', () {
    test('coudre une robe', () {
      expect(CategoryClassifier.detectStrongMatch('Coudre une robe facile pour débutante'),
          'Couture');
    });
  });
}
