# Trabalho Prático II — Erlang

Experimento de soma paralela de resultados de uma carga computacional determinística, implementado com processos Erlang e troca de mensagens.

## Requisitos

- Erlang/OTP (compilador `erlc` e runtime `erl`)
- Linux, macOS ou Windows com Erlang instalado

## Compilar e executar

No terminal, dentro desta pasta:

```sh
erlc parallel_lab.erl
erl -noshell -pa . -s parallel_lab main -s init stop
```

A saída é CSV no terminal, com tamanho da entrada, quantidade de trabalhadores, mediana do tempo em milissegundos, speedup, eficiência e resultado calculado. A execução usa três repetições por configuração e seleciona a mediana. O programa também confere que o resultado paralelo coincide com o sequencial.

## Arquivos

- `parallel_lab.erl`: código-fonte do experimento.
- `resultados.csv`: medições obtidas nesta máquina.
- `relatorio.md` e `relatorio.docx`: relatório com método, resultados e respostas da análise.

O executável `.beam` é gerado ao compilar e não precisa ser enviado.

As medições são de uma execução local específica e podem variar conforme hardware, carga do sistema e versão do Erlang. Não são resultados de um cluster físico.
