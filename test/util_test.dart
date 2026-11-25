import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_financeiro/util.dart';

DateTime _emDias(int n) {
  final h = hoje();
  return DateTime(h.year, h.month, h.day + n);
}

void main() {
  group('formatarReais (RN-FIN-02)', () {
    test('formata valor simples', () {
      expect(formatarReais(500), 'R\$ 500,00');
    });
    test('usa ponto como separador de milhar', () {
      expect(formatarReais(15000), 'R\$ 15.000,00');
      expect(formatarReais(1234567.891), 'R\$ 1.234.567,89');
    });
    test('formata zero', () {
      expect(formatarReais(0), 'R\$ 0,00');
    });
    test('valores negativos recebem sinal', () {
      expect(formatarReais(-50.5), '-R\$ 50,50');
    });
    test('diferença de arredondamento minúscula não gera "-R\$ 0,00"', () {
      expect(formatarReais(-0.001), 'R\$ 0,00');
    });
  });

  group('parseValor', () {
    test('aceita formato brasileiro', () {
      expect(parseValor('1.500,50'), 1500.5);
      expect(parseValor('12,5'), 12.5);
    });
    test('ignora o prefixo R\$ e espaços', () {
      expect(parseValor('R\$ 500,00'), 500);
    });
    test('trata ponto de milhar sem decimais', () {
      expect(parseValor('1.500'), 1500);
    });
    test('aceita ponto decimal', () {
      expect(parseValor('10.5'), 10.5);
    });
    test('retorna null para texto vazio ou inválido', () {
      expect(parseValor(''), isNull);
      expect(parseValor('   '), isNull);
      expect(parseValor('abc'), isNull);
    });
  });

  group('validarValor (RN-FIN-01)', () {
    test('rejeita nulo, vazio e texto', () {
      expect(validarValor(null), 'Informe um valor válido.');
      expect(validarValor(''), 'Informe um valor válido.');
      expect(validarValor('abc'), 'Informe um valor válido.');
    });
    test('rejeita zero e negativo', () {
      expect(validarValor('0'), 'O valor deve ser maior que zero.');
      expect(validarValor('-5'), 'O valor deve ser maior que zero.');
    });
    test('aceita valor positivo', () {
      expect(validarValor('100'), isNull);
      expect(validarValor('0,01'), isNull);
    });
  });

  group('validarSenha (RN-PER-01)', () {
    test('rejeita menos de 6 caracteres', () {
      expect(validarSenha(null), isNotNull);
      expect(validarSenha('12345'), isNotNull);
    });
    test('aceita 6 ou mais caracteres', () {
      expect(validarSenha('123456'), isNull);
    });
  });

  group('validarEmail', () {
    test('rejeita vazio', () {
      expect(validarEmail(null), 'Informe seu e-mail.');
      expect(validarEmail('  '), 'Informe seu e-mail.');
    });
    test('rejeita formatos inválidos', () {
      expect(validarEmail('abc'), 'Informe um e-mail válido.');
      expect(validarEmail('a@b'), 'Informe um e-mail válido.');
      expect(validarEmail('a b@c.com'), 'Informe um e-mail válido.');
    });
    test('aceita e-mail válido', () {
      expect(validarEmail('nome@dominio.com'), isNull);
    });
  });

  group('datas e percentuais', () {
    test('formatarData e formatarDataCurta', () {
      expect(formatarData(DateTime(2026, 3, 5)), '05/03/2026');
      expect(formatarDataCurta(DateTime(2026, 3, 5)), '05/03');
    });
    test('formatarPercentual arredonda', () {
      expect(formatarPercentual(0.456), '46%');
      expect(formatarPercentual(0.03), '3%');
      expect(formatarPercentual(1), '100%');
    });
    test('diasAte conta dias de calendário', () {
      expect(diasAte(hoje()), 0);
      expect(diasAte(_emDias(10)), 10);
      expect(diasAte(_emDias(-3)), -3);
    });
  });
}
