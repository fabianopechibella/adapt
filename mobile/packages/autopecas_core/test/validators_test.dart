import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plate', () {
    test('aceita Mercosul e padrão antigo, com hífen, espaço e minúsculas', () {
      expect(Plate.tryParse('abc1d23')?.value, 'ABC1D23');
      expect(Plate.tryParse('KJH-5544')?.value, 'KJH5544');
      expect(Plate.tryParse('kjh 5544')?.display, 'KJH-5544');
      expect(Plate.tryParse('ABC1D23')!.isMercosul, isTrue);
    });

    test('rejeita formatos inválidos', () {
      expect(Plate.isValid('AB1D234'), isFalse);
      expect(Plate.isValid('ABCD123'), isFalse);
      expect(Plate.isValid(''), isFalse);
    });

    test('encontra a placa no meio de uma mensagem', () {
      expect(Plate.findIn('preciso de embreagem do onix placa abc-1d23 urgente')?.value, 'ABC1D23');
      expect(Plate.findIn('sem placa aqui'), isNull);
    });
  });

  group('Cnpj', () {
    test('valida CNPJ numérico', () {
      expect(Cnpj.isValid('11.222.333/0001-81'), isTrue);
      expect(Cnpj.isValid('11.222.333/0001-82'), isFalse);
      expect(Cnpj.isValid('00000000000000'), isFalse);
    });

    test('valida CNPJ alfanumérico (vigente desde julho de 2026)', () {
      expect(Cnpj.isValid('12.ABC.345/01DE-35'), isTrue);
      expect(Cnpj.isValid('12ABC34501DE36'), isFalse);
      expect(Cnpj.tryParse('12abc34501de35')!.display, '12.ABC.345/01DE-35');
    });
  });

  test('Money formata em reais', () {
    expect(const Money(68990).format(), contains('689,90'));
    expect((const Money(100) * 3 + const Money(50)).cents, 350);
  });
}
