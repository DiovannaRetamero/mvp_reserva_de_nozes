import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_financeiro/modelos.dart';
import 'package:mvp_financeiro/util.dart';

DateTime _emDias(int n) {
  final h = hoje();
  return DateTime(h.year, h.month, h.day + n);
}

Caixinha _cx({
  String id = 'c1',
  String nome = 'Meta',
  double alvo = 1000,
  DateTime? limite,
  int prioridade = 1,
  bool reserva = false,
  StatusCaixinha status = StatusCaixinha.ativa,
  double maximo = 0,
  DateTime? criadoEm,
}) {
  return Caixinha(
    id: id,
    nome: nome,
    valorAlvo: alvo,
    dataLimite: limite ?? _emDias(200),
    prioridade: prioridade,
    reserva: reserva,
    status: status,
    valorMaximo: maximo,
    criadoEm: criadoEm ?? hoje(),
  );
}

var _seq = 0;
Movimentacao _mov(
  TipoMov tipo,
  double valor, {
  String cx = 'c1',
  DateTime? data,
  DateTime? criadoEm,
}) {
  _seq++;
  return Movimentacao(
    id: 'm$_seq',
    tipo: tipo,
    nome: 'mov $_seq',
    valor: valor,
    data: data ?? hoje(),
    categoria: 'Outro',
    caixinhaId: cx,
    descricao: '',
    criadoEm: criadoEm ?? hoje(),
  );
}

void main() {
  group('Resumo: saldo e progresso (RF-FIN-01.1, RF-FIN-04.1)', () {
    test('saldo é aportes menos retiradas da caixinha', () {
      final r = Resumo([_cx()], [
        _mov(TipoMov.aporte, 300),
        _mov(TipoMov.aporte, 200),
        _mov(TipoMov.retirada, 100),
        _mov(TipoMov.aporte, 999, cx: 'outra'),
      ]);
      expect(r.saldoDe('c1'), 400);
    });

    test('progresso é saldo / valor alvo', () {
      final c = _cx(alvo: 1000);
      final r = Resumo([c], [_mov(TipoMov.aporte, 500)]);
      expect(r.progressoDe(c), 0.5);
    });

    test('progresso é 0 quando o valor alvo é 0', () {
      final c = _cx(alvo: 0);
      final r = Resumo([c], [_mov(TipoMov.aporte, 500)]);
      expect(r.progressoDe(c), 0);
    });
  });

  group('Resumo: totais', () {
    test('saldoAtual soma apenas caixinhas ativas (RF-FIN-09)', () {
      final r = Resumo(
        [
          _cx(id: 'a'),
          _cx(id: 'b', status: StatusCaixinha.concluida),
        ],
        [
          _mov(TipoMov.aporte, 300, cx: 'a'),
          _mov(TipoMov.aporte, 700, cx: 'b'),
        ],
      );
      expect(r.saldoAtual, 300);
    });

    test('metasAtivas ignora reserva e caixinhas não ativas (RN-CAI-03)', () {
      final r = Resumo([
        _cx(id: 'r', reserva: true),
        _cx(id: 'm1'),
        _cx(id: 'm2'),
        _cx(id: 'm3', status: StatusCaixinha.concluida),
        _cx(id: 'm4', status: StatusCaixinha.desistida),
      ], const []);
      expect(r.metasAtivas, 2);
      expect(r.metasAtivas < limiteMetasAtivas, isTrue);
    });

    test('aportadoNoMes soma só aportes do mês atual (RF-CAI-07)', () {
      final h = hoje();
      final r = Resumo([_cx()], [
        _mov(TipoMov.aporte, 100),
        _mov(TipoMov.aporte, 50, data: DateTime(h.year, h.month - 1, 15)),
        _mov(TipoMov.retirada, 30),
      ]);
      expect(r.aportadoNoMes('c1'), 100);
    });

    test('valorMaximoDe nunca fica abaixo do saldo (RN-CAI-07)', () {
      final c = _cx(maximo: 500);
      expect(
        Resumo([c], [_mov(TipoMov.aporte, 800)]).valorMaximoDe(c),
        800,
      );
      expect(
        Resumo([c], [_mov(TipoMov.aporte, 200)]).valorMaximoDe(c),
        500,
      );
    });
  });

  group('Resumo: ordenação (RN-CAI-04)', () {
    test('reserva primeiro, depois prioridade', () {
      final r = Resumo([
        _cx(id: 'baixa', prioridade: 2),
        _cx(id: 'res', reserva: true, prioridade: 2),
        _cx(id: 'alta', prioridade: 0),
      ], const []);
      expect(r.ativas.map((c) => c.id), ['res', 'alta', 'baixa']);
    });

    test('empate de prioridade: prazo mais próximo primeiro', () {
      final r = Resumo([
        _cx(id: 'longe', limite: _emDias(300)),
        _cx(id: 'perto', limite: _emDias(100)),
      ], const []);
      expect(r.ativas.map((c) => c.id), ['perto', 'longe']);
    });

    test('arquivadas só traz não ativas, em ordem alfabética', () {
      final r = Resumo([
        _cx(id: 'a', nome: 'Viagem', status: StatusCaixinha.concluida),
        _cx(id: 'b', nome: 'Carro', status: StatusCaixinha.desistida),
        _cx(id: 'c', nome: 'Ativa'),
      ], const []);
      expect(r.arquivadas.map((c) => c.nome), ['Carro', 'Viagem']);
    });

    test('movsDe ordena da mais recente para a mais antiga', () {
      final antiga = _mov(TipoMov.aporte, 10, data: _emDias(-5));
      final recente = _mov(TipoMov.aporte, 20, data: _emDias(-1));
      final r = Resumo([_cx()], [antiga, recente]);
      expect(r.movsDe('c1').first.id, recente.id);
    });
  });

  group('faixaDoPrazo (RN-CAI-01)', () {
    test('menos de 30 dias ou vencido é urgente', () {
      expect(faixaDoPrazo(_emDias(10)), FaixaPrazo.urgente);
      expect(faixaDoPrazo(_emDias(29)), FaixaPrazo.urgente);
      expect(faixaDoPrazo(_emDias(-5)), FaixaPrazo.urgente);
    });
    test('de 30 a 90 dias é atenção', () {
      expect(faixaDoPrazo(_emDias(30)), FaixaPrazo.atencao);
      expect(faixaDoPrazo(_emDias(90)), FaixaPrazo.atencao);
    });
    test('mais de 90 dias é tranquilo', () {
      expect(faixaDoPrazo(_emDias(91)), FaixaPrazo.tranquilo);
    });
  });

  group('validarSaldos (RN-FIN-03)', () {
    final c = _cx(nome: 'Reserva');

    test('retirada maior que o saldo é bloqueada e informa o disponível', () {
      final r = Resumo([c], [_mov(TipoMov.aporte, 100)]);
      final erro = validarSaldos(
        r,
        adicionar: _mov(TipoMov.retirada, 150),
      );
      expect(erro, contains('não pode ser maior'));
      expect(erro, contains('R\$ 100,00'));
    });

    test('retirada igual ao saldo é permitida', () {
      final r = Resumo([c], [_mov(TipoMov.aporte, 100)]);
      expect(validarSaldos(r, adicionar: _mov(TipoMov.retirada, 100)), isNull);
    });

    test('novo aporte é sempre permitido', () {
      final r = Resumo([c], const []);
      expect(validarSaldos(r, adicionar: _mov(TipoMov.aporte, 50)), isNull);
    });

    test('remover aporte que já foi parcialmente retirado é bloqueado', () {
      final aporte = _mov(TipoMov.aporte, 100);
      final r = Resumo([c], [aporte, _mov(TipoMov.retirada, 80)]);
      final erro = validarSaldos(r, remover: aporte);
      expect(erro, contains('negativo'));
      expect(erro, contains('Reserva'));
    });

    test('remover uma retirada é permitido', () {
      final retirada = _mov(TipoMov.retirada, 80);
      final r = Resumo([c], [_mov(TipoMov.aporte, 100), retirada]);
      expect(validarSaldos(r, remover: retirada), isNull);
    });
  });

  group('pontosSaldo (gráfico do dashboard)', () {
    test('acumula o saldo e agrupa movimentações do mesmo dia', () {
      final d1 = _emDias(-10);
      final d3 = _emDias(-8);
      final pontos = pontosSaldo([
        _mov(TipoMov.aporte, 100, data: d1),
        _mov(TipoMov.retirada, 30, data: d1),
        _mov(TipoMov.aporte, 50, data: d3),
      ]);
      expect(pontos.length, 2);
      expect(pontos[0].saldo, 70);
      expect(pontos[1].saldo, 120);
    });

    test('com início, o saldo anterior vira o ponto de abertura', () {
      final inicio = _emDias(-9);
      final pontos = pontosSaldo(
        [
          _mov(TipoMov.aporte, 100, data: _emDias(-10)),
          _mov(TipoMov.aporte, 50, data: _emDias(-8)),
        ],
        inicio: inicio,
      );
      expect(pontos.first.data, inicio);
      expect(pontos.first.saldo, 100);
      expect(pontos.last.saldo, 150);
    });
  });

  group('gerarAlertas (RF-CAI-12)', () {
    test('caixinha em dia não gera alertas', () {
      final c = _cx();
      final r = Resumo([c], [_mov(TipoMov.aporte, 500)]);
      expect(gerarAlertas(r), isEmpty);
    });

    test('30 dias sem aporte gera alerta de inatividade (RF-CAI-12.1)', () {
      final c = _cx(criadoEm: _emDias(-40));
      final alertas = gerarAlertas(Resumo([c], const []));
      expect(alertas.map((a) => a.tipo), [TipoAlerta.inatividade]);
    });

    test('90% ou mais (e menos de 100%) gera alerta de quase concluída (RF-CAI-12.2)', () {
      final c = _cx();
      final r = Resumo([c], [_mov(TipoMov.aporte, 950)]);
      final alertas = gerarAlertas(r);
      expect(alertas.map((a) => a.tipo), [TipoAlerta.quaseConcluida]);
      expect(alertas.first.texto, contains('Falta pouco'));
    });

    test('meta concluída (100%) não gera alerta de quase concluída', () {
      final c = _cx();
      final r = Resumo([c], [_mov(TipoMov.aporte, 1000)]);
      expect(gerarAlertas(r), isEmpty);
    });

    test('prazo urgente gera alerta com os dias restantes (RF-CAI-12.3)', () {
      final c = _cx(limite: _emDias(10));
      final r = Resumo([c], [_mov(TipoMov.aporte, 100)]);
      final alertas = gerarAlertas(r);
      expect(alertas.map((a) => a.tipo), [TipoAlerta.prazo]);
      expect(alertas.first.texto, contains('Faltam 10 dia(s)'));
    });

    test('prazo vencido informa há quantos dias', () {
      final c = _cx(limite: _emDias(-3));
      final r = Resumo([c], [_mov(TipoMov.aporte, 100)]);
      expect(gerarAlertas(r).first.texto, contains('venceu há 3 dia(s)'));
    });

    test('meta concluída com prazo urgente não gera alerta de prazo', () {
      final c = _cx(limite: _emDias(5));
      final r = Resumo([c], [_mov(TipoMov.aporte, 1000)]);
      expect(gerarAlertas(r), isEmpty);
    });
  });
}
