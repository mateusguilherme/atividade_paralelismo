# Trabalho Prático II — Processamento paralelo em Erlang

**Integrantes:** ____________________________________________  
**Disciplina:** _____________________________________________

## 1. Proposta e hipótese

O problema investigado foi o custo de executar uma carga CPU-bound independente em modo sequencial e com diferentes quantidades de processos Erlang. Cada item da entrada executa uma recorrência inteira determinística; ao final, os valores são somados. A entrada é dividida em blocos, um processo calcula cada bloco e envia sua soma parcial ao processo coordenador por mensagem.

Hipótese: aumentar a quantidade de processos deve reduzir o tempo enquanto houver trabalho suficiente para compensar a criação de processos e a comunicação. Espera-se que o ganho não seja linear, sobretudo nas entradas pequenas, devido à sobrecarga e à capacidade limitada de processamento simultâneo.

**Variável independente:** quantidade de trabalhadores (1, 2, 4 e 8) e tamanho da entrada (200, 800 e 2.000 itens).  
**Variáveis dependentes:** tempo mediano, speedup e eficiência.  
**Controles:** 2.000 iterações por item, mesmo algoritmo e máquina, mesma versão do Erlang, três repetições por configuração e resultado numérico conferido em todas as configurações. O caso com um trabalhador executa diretamente no processo principal e representa a referência sequencial.

## 2. Implementação e execução

O código em `parallel_lab.erl` usa `spawn/1` para criar processos trabalhadores e troca de mensagens com `!` e `receive`, seguindo o padrão dos exemplos de Erlang da disciplina. Os exemplos usam `spawn/3`; a forma `spawn/1`, que recebe uma função anônima, mantém a função `worker/5` privada ao módulo. O PID do coordenador é passado aos trabalhadores. Cada resposta é uma tupla `{partial, Referência, Soma}`, com átomo identificador e referência da execução; o coordenador seleciona as respostas correspondentes na sua caixa de correio e combina as somas. A medição usa relógio monotônico. Para cada configuração foram feitas três execuções; a mediana reduz a influência de uma medição atípica. Speedup = tempo sequencial / tempo paralelo. Eficiência = speedup / quantidade de trabalhadores.

Para compilar e executar: `erlc parallel_lab.erl` e `erl -noshell -pa . -s parallel_lab main -s init stop`. As medições foram obtidas em Erlang/OTP 26, Linux x86_64, processador AMD Ryzen 7 5700U, com 16 schedulers Erlang disponíveis. O CSV completo está em `resultados.csv`.

## 3. Dados coletados

| Itens | Processos | Tempo (ms) | Speedup | Eficiência |
|---:|---:|---:|---:|---:|
| 200 | 1 | 3,283 | 1,000 | 1,000 |
| 200 | 2 | 2,056 | 1,597 | 0,798 |
| 200 | 4 | 1,781 | 1,843 | 0,461 |
| 200 | 8 | 0,880 | 3,731 | 0,466 |
| 800 | 1 | 13,164 | 1,000 | 1,000 |
| 800 | 2 | 6,779 | 1,942 | 0,971 |
| 800 | 4 | 4,607 | 2,857 | 0,714 |
| 800 | 8 | 2,682 | 4,908 | 0,614 |
| 2.000 | 1 | 33,330 | 1,000 | 1,000 |
| 2.000 | 2 | 20,081 | 1,660 | 0,830 |
| 2.000 | 4 | 10,381 | 3,211 | 0,803 |
| 2.000 | 8 | 5,960 | 5,592 | 0,699 |

## 4. Análise e respostas

**Impacto da paralelização:** todas as configurações paralelas medidas terminaram antes da referência sequencial. Na maior entrada, oito processos reduziram o tempo de 33,330 ms para 5,960 ms, speedup de 5,59 vezes. Para 200 itens, o melhor tempo foi 0,880 ms com oito processos, com eficiência de 0,466.

**O ganho foi linear?** Não. Se fosse linear, oito processos produziriam speedup próximo de 8. O observado foi de 3,73 a 5,59 conforme a entrada. A parcela serial, o custo de iniciar processos, repartir blocos e trocar mensagens limitam o ganho. Com entrada pequena, essa sobrecarga representa uma parte maior do tempo total. A eficiência também cai quando se aumenta a quantidade de trabalhadores.

**Influência de Erlang:** conforme o material da disciplina, Erlang usa processos leves e troca de mensagens para coordenar atividades. A divisão em blocos permite que os trabalhadores calculem independentemente, sem compartilhar estado mutável; o processo coordenador recolhe as mensagens. Essa organização simplifica a comunicação, mas criar processos, escaloná-los e receber resultados tem custo. Concorrência descreve as tarefas em progresso sobrepostas; a execução paralela simultânea depende dos schedulers e núcleos disponíveis. Aqui foram usados até oito trabalhadores numa máquina com 16 schedulers Erlang disponíveis, sem comunicação de rede ou cluster.

**Gargalos e limite prático:** os resultados sugerem sobrecarga de coordenação e limite de núcleos físicos/recursos disponíveis. A eficiência cai de quatro para oito processos nas entradas 800 e 2.000; nessa última, oito ainda reduzem o tempo porque há mais trabalho para distribuir. Portanto, o limite depende do tamanho da tarefa: processos adicionais deixam de compensar quando sua sobrecarga supera o trabalho que conseguem executar em paralelo. Os tempos pequenos também são sensíveis à carga do sistema e devem ser interpretados como indicativos.

**Como melhorar:** repetir em mais máquinas e versões do Erlang, testar mais tamanhos e quantidades de processos, executar várias rodadas completas em ordem aleatória, medir desvio além da mediana, comparar agrupamento de tarefas e medir separadamente o custo de comunicação. Uma extensão com nós Erlang em computadores diferentes permitiria estudar latência e escalabilidade distribuída.

## Relação com os conteúdos da disciplina

O experimento aplica os exemplos de processos Erlang apresentados no material: criação de processos com `spawn` (na forma `spawn/1`, com função anônima), envio com `!`, recebimento com `receive`, identificação de mensagens por tuplas e execução concorrente de funções. Também relaciona o número de trabalhadores ao paralelismo em arquiteturas com múltiplos processadores e discute o custo de coordenação. Foram consultados os PDFs e exemplos Erlang disponibilizados em `~/Downloads/pp/`. Os resultados são locais e ilustram o efeito do paralelismo nesta carga; não representam uma avaliação de cluster.
