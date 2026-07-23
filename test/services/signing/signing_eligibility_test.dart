import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/signing/signing_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BrowseItem file(
    String name, {
    List<String>? operations = const ['update'],
    String type = 'file',
    bool isDepartment = false,
  }) {
    return BrowseItem(
      id: 'node-1',
      name: name,
      type: type,
      allowableOperations: operations,
      isDepartment: isDepartment,
    );
  }

  bool eligible(
    BrowseItem item, {
    String instanceType = 'Classic',
    bool isOnline = true,
  }) {
    return SigningEligibility.isEligible(
      item: item,
      instanceType: instanceType,
      isOnline: isOnline,
    );
  }

  test('Classic pdf with write permission is eligible', () {
    expect(eligible(file('contract.pdf')), isTrue);
  });

  test(
    'Classic supported Office and image extensions with write permission are eligible',
    () {
      for (final name in [
        'agreement.doc',
        'agreement.docx',
        'scan.jpg',
        'scan.jpeg',
        'scan.png',
      ]) {
        expect(eligible(file(name)), isTrue, reason: name);
      }
    },
  );

  test('Classic unsupported extension is ineligible', () {
    expect(eligible(file('notes.txt')), isFalse);
  });

  test('Classic file without write permission is ineligible', () {
    expect(eligible(file('contract.pdf', operations: const ['read'])), isFalse);
  });

  test('Angora supported file with write permission is ineligible', () {
    expect(eligible(file('contract.pdf'), instanceType: 'Angora'), isFalse);
  });

  test('Folder and department are ineligible', () {
    expect(eligible(file('Folder', type: 'folder')), isFalse);
    expect(
      eligible(file('Department', type: 'folder', isDepartment: true)),
      isFalse,
    );
  });

  test(
    'Classic document type with supported extension and write permission is eligible',
    () {
      expect(eligible(file('contract.pdf', type: 'document')), isTrue);
    },
  );

  test('Offline state is ineligible', () {
    expect(eligible(file('contract.pdf'), isOnline: false), isFalse);
  });
}
