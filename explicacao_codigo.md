# Explicação do `parallel_lab.erl`

## Visão geral

O programa mede quanto a paralelização acelera um cálculo pesado de CPU. Ele soma o resultado de `Size` itens, cada um custando 2000 iterações de um gerador pseudoaleatório. Faz isso com 1, 2, 4 e 8 processos e imprime um CSV com tempo, *speedup* e eficiência.

O arquivo está dividido em duas seções:

| Seção | Funções | Linhas |
|---|---|---|
| Públicas (exportadas) | `main/0`, `run/3` | 8–36 |
| Privadas (internas ao módulo) | `parallel_run/3`, `worker/5`, `chunk_sum/4`, `item_work/2`, `work_loop/2`, `collect/3`, `median_ms/2` | 42–82 |

---

## Cabeçalho (linhas 1–6)

```erlang
-module(parallel_lab).
```

Declara o nome do módulo. Ele precisa ser igual ao nome do arquivo (`parallel_lab.erl`).

```erlang
-export([main/0, run/3]).
```

Lista as funções visíveis fora do módulo, no formato `nome/aridade` (aridade é o número de argumentos). São essas que definem a seção de funções públicas. As que não estão na lista só podem ser chamadas de dentro do próprio módulo, ou seja, são privadas.

Linhas 4–6 e 38–40: comentários que marcam o início de cada seção. Em Erlang o comentário começa com `%`, e `%%` é a convenção para comentários de bloco.

---

## Funções públicas

### `main/0`: o experimento (linhas 8–30)

Ponto de entrada do programa.

```erlang
main() ->
    Sizes = [200, 800, 2000],     % quantidades de itens a processar
    WorkerCounts = [1, 2, 4, 8],  % números de processos a testar
    Repeats = 3,                  % cada medição roda 3 vezes (usa a mediana)
    Iterations = 2000,            % custo de cada item
```

Variáveis começam com letra maiúscula e são **imutáveis**: recebem valor uma vez só. `->` inicia o corpo da função, `,` separa expressões e `.` termina a função.

Os quatro parâmetros do experimento ficam juntos no topo. `Iterations` é declarado uma vez e usado nas duas chamadas ao `run`, então a versão sequencial e a paralela sempre calculam a mesma coisa. O nome também deixa claro que esse `2000` não tem relação com o `2000` da lista `Sizes`.

```erlang
    io:format("size,workers,median_ms,speedup,efficiency,result~n"),
```

Imprime o cabeçalho do CSV. `~n` é a quebra de linha.

```erlang
    lists:foreach(fun(Size) ->
```

Erlang não tem `for`. `lists:foreach(Fun, Lista)` aplica uma função anônima (`fun ... end`) a cada elemento. Aqui é o laço externo, sobre os tamanhos.

```erlang
        {SeqMs, SeqResult} = median_ms(fun() -> run(Size, 1, Iterations) end, Repeats),
```

Mede a versão **sequencial** (1 worker), que serve de referência. `median_ms` devolve uma tupla `{tempo, resultado}`, e o `=` aqui faz **pattern matching**: desmonta a tupla em duas variáveis. O `fun() -> ... end` embrulha a chamada para que `median_ms` decida quando executá-la (e quantas vezes).

```erlang
        lists:foreach(fun(Workers) ->
```

Laço interno, sobre o número de workers. A lista se chama `WorkerCounts` e cada elemento se chama `Workers`, no mesmo padrão de `Sizes`/`Size`. Com isso, o nome é o mesmo do parâmetro de `run/3` e `parallel_run/3`.

```erlang
            {ParMs, ParResult} = case Workers of
                1 -> {SeqMs, SeqResult};
                _ -> median_ms(fun() -> run(Size, Workers, Iterations) end, Repeats)
            end,
```

`case` escolhe pelo padrão. Com `Workers = 1`, reaproveita a medição sequencial em vez de medir de novo. Com qualquer outro valor (`_` casa com tudo), mede a versão paralela. As cláusulas são separadas por `;`. Os nomes `ParMs` e `ParResult` formam par com `SeqMs` e `SeqResult`.

```erlang
            Speedup = SeqMs / ParMs,
            Efficiency = Speedup / Workers,
```

- **Speedup** = tempo sequencial / tempo paralelo. Com 4 workers, o ideal seria 4.
- **Eficiência** = speedup / workers. O ideal seria 1.0 (100%).

O operador `/` sempre devolve float. Divisão inteira é `div`.

```erlang
            io:format("~B,~B,~.3f,~.4f,~.4f,~B~n",
                      [Size, Workers, ParMs, Speedup, Efficiency, ParResult]),
```

Imprime uma linha do CSV. Diretivas usadas: `~B` é inteiro em base 10, `~.3f` é float com 3 casas, `~.4f` é float com 4 casas. Os valores vão numa lista.

```erlang
            case ParResult =:= SeqResult of
                true -> ok;
                false -> erlang:error({incorrect_result, Size, Workers})
            end
```

Confere se o resultado paralelo é **idêntico** ao sequencial. `=:=` é igualdade exata (`==` consideraria `1 == 1.0` verdadeiro, `=:=` não). Se der diferente, lança uma exceção com uma tupla que descreve o erro. `ok` é um **átomo**, uma constante simbólica (minúscula).

Como o `io:format` vem antes, a linha com o resultado errado ainda aparece no CSV. Logo depois, o `erlang:error` interrompe o `main`, e as configurações que faltavam não rodam. Veja abaixo quando isso pode acontecer.

```erlang
        end, WorkerCounts)
    end, Sizes).
```

Fecham as duas funções anônimas e passam as listas sobre as quais cada `foreach` itera.

#### Quando o `incorrect_result` pode disparar

Com o código atual, nunca deveria disparar. A verificação funciona como uma **asserção**, que só pega bugs introduzidos no futuro. O resultado sempre bate porque:

1. **Inteiros em Erlang não estouram.** Eles crescem sem limite (*bignum*). A soma de inteiros é exata e não depende da ordem em que as somas parciais chegam.
2. **O trabalho é determinístico.** O `item_work(N, Iterations)` sempre devolve o mesmo valor para o mesmo `N`, em qualquer processo.
3. **Cada item é processado exatamente uma vez.** As faixas `Start..Stop` cobrem de 1 a `Size` sem buraco e sem sobreposição.
4. **Toda resposta contada é desta execução.** O `Ref` no `receive` descarta mensagens de outras execuções, e o `collect` espera exatamente uma resposta por processo criado.

Ela dispararia se alguma dessas garantias fosse quebrada. Por exemplo: faixas sobrepostas (um item somado duas vezes), o `collect` retornando antes de receber todas as respostas, um acumulador em float (a soma passa a depender da ordem) ou o uso de `rand` no `item_work` (a semente é diferente em cada processo).

A verificação vale a pena porque, em benchmarks de paralelismo, os bugs costumam deixar a versão paralela **mais rápida**: ela calcula menos e mostra um speedup falso. Comparar com o resultado sequencial separa "ficou mais rápido" de "ficou mais rápido porque calculou menos". O custo é uma comparação de inteiros por linha, feita fora do trecho cronometrado.

Falta de resposta **não** causa `incorrect_result`, e sim travamento. É o caso de um worker que morre com exceção ou de um `collect` que espera mais mensagens do que existem: o `receive` fica esperando para sempre.

### `run/3`: decide entre sequencial e paralelo (linhas 32–36)

Pública para poder ser chamada direto no shell, por exemplo `parallel_lab:run(2000, 4, 2000)`.

```erlang
run(Size, Workers, Iterations) when Size > 0, Workers > 0 ->
```

`when ...` é uma **guarda**: a função só aceita a chamada se as condições forem verdadeiras (a vírgula na guarda significa E). Uma chamada como `run(0, 2, 10)` falha com `function_clause`.

O `main` sempre passa valores positivos, mas a guarda protege quem chama o `run/3` direto. Sem ela, um tamanho negativo devolveria `0` sem avisar nada. Já `Workers = 0` causaria uma divisão por zero dentro de `parallel_run`, e `Workers` negativo causaria um erro dentro de `lists:seq`, os dois longe da causa real. Com a guarda, qualquer valor inválido falha logo na entrada, com uma mensagem que aponta para `run/3` e mostra os argumentos recebidos.

```erlang
    case Workers of
        1 -> chunk_sum(1, Size, Iterations, 0);
        _ -> parallel_run(Size, Workers, Iterations)
    end.
```

Com 1 worker, soma os itens de 1 a `Size` no próprio processo, sem criar outros. Caso contrário, distribui o trabalho.

---

## Funções privadas

### `parallel_run/3`: divide e dispara processos (linhas 42–51)

```erlang
    Parent = self(),
```

`self()` devolve o PID (identificador) do processo atual. Ele fica guardado para que os workers saibam para quem mandar o resultado.

```erlang
    Chunk = (Size + Workers - 1) div Workers,
```

Tamanho de cada pedaço, arredondado **para cima** (divisão teto). Exemplo: 10 itens e 4 workers dão `13 div 4 = 3`, então os pedaços são 3, 3, 3 e 1.

```erlang
    Ref = make_ref(),
```

Cria uma **referência única** na VM. Ela vai junto em cada mensagem, para o pai só aceitar respostas *desta* execução e não confundir com mensagens antigas ou de outra origem.

```erlang
    Pids = [begin
        Start = ((Index - 1) * Chunk) + 1,
        Stop = min(Index * Chunk, Size),
        spawn(fun() -> worker(Parent, Ref, Start, Stop, Iterations) end)
    end || Index <- lists:seq(1, Workers), ((Index - 1) * Chunk) < Size],
```

É uma **list comprehension** (`[Expr || Gerador, Filtro]`):

- `Index <- lists:seq(1, Workers)`: percorre 1, 2, …, Workers.
- `((Index - 1) * Chunk) < Size`: **filtro**. Só cria o worker se o pedaço começa dentro do intervalo, para não ter workers com faixa vazia.
- `begin ... end`: agrupa várias expressões numa só.
- `Start`/`Stop`: limites da faixa do worker. O `min` impede que o último passe de `Size`.
- `spawn(Fun)`: cria um **processo Erlang novo** (leve, não é thread do SO), que executa a função anônima e devolve o PID dele. A função anônima é uma *closure*: ela "captura" os valores de `Parent`, `Ref`, `Start`, `Stop` e `Iterations` no momento em que é criada, e o novo processo os recebe prontos.

O resultado é a lista `Pids`, com um PID para cada processo realmente criado.

**Por que `spawn/1` e não `spawn/3`:** os exemplos da disciplina usam `spawn(Módulo, Função, Args)`. Essa forma chama a função por nome, como se viesse de fora do módulo, e por isso só funciona com funções exportadas. Com `spawn/1`, a chamada a `worker` acontece dentro de uma função anônima definida no próprio módulo, então `worker/5` pode ficar privada. O comportamento é o mesmo.

```erlang
    collect(Ref, length(Pids), 0).
```

Espera as respostas. O segundo argumento é quantas mensagens aguardar, exatamente o número de processos criados, e `0` é a soma inicial.

### `worker/5`: o que cada processo faz (linhas 53–55)

```erlang
worker(Parent, Ref, Start, Stop, Iterations) ->
    Sum = chunk_sum(Start, Stop, Iterations, 0),
    Parent ! {partial, Ref, Sum}.
```

Calcula a soma parcial da sua faixa e **envia uma mensagem** ao pai com o operador `!`. A mensagem é a tupla `{partial, Ref, Sum}`. Depois disso a função termina e o processo morre.

Fica logo depois de `parallel_run`, que é a única função que a usa.

### `chunk_sum/4`: soma uma faixa de itens (linhas 57–60)

```erlang
chunk_sum(Current, Stop, _Iterations, Acc) when Current > Stop -> Acc;
```

Caso base: passou do fim, devolve o acumulador. O `_` no início de `_Iterations` avisa o compilador que a variável não é usada nessa cláusula, o que evita um warning.

```erlang
chunk_sum(Current, Stop, Iterations, Acc) ->
    chunk_sum(Current + 1, Stop, Iterations,
              Acc + item_work(Current, Iterations)).
```

Caso recursivo: processa o item `Current`, soma no acumulador e chama a si mesma com o próximo. Essa é a forma de fazer laço em Erlang: **recursão de cauda** com acumulador, que roda em memória constante como um `while`. As duas cláusulas da mesma função são separadas por `;` e a função termina com `.`.

### `item_work/2` e `work_loop/2`: a carga de CPU (linhas 62–64)

```erlang
item_work(Seed, Iterations) -> work_loop(Iterations, Seed rem 1000003).
```

Usa o número do item como semente, reduzido módulo 1000003 (um primo). `rem` é o resto da divisão.

```erlang
work_loop(0, Value) -> Value;
work_loop(N, Value) -> work_loop(N - 1, (Value * 48271 + 1) rem 2147483647).
```

Aplica `N` vezes um **gerador congruencial linear** (a constante 48271 com módulo 2³¹−1 é a do MINSTD/Park-Miller). A primeira cláusula usa pattern matching direto no literal `0`: quando o contador zera, devolve o valor. Isso é só "trabalho de CPU" **determinístico**: o mesmo item sempre dá o mesmo número, e é isso que permite comparar o resultado paralelo com o sequencial.

### `collect/3`: recebe as somas parciais (linhas 66–70)

```erlang
collect(_Ref, 0, Sum) -> Sum;
```

Quando não falta ninguém, devolve a soma total.

```erlang
collect(Ref, Remaining, Sum) ->
    receive
        {partial, Ref, Partial} -> collect(Ref, Remaining - 1, Sum + Partial)
    end.
```

`receive` **bloqueia** até chegar na caixa de correio do processo uma mensagem que case com o padrão. Detalhe importante: `Ref` **já tem valor**, então no padrão ela funciona como um teste de igualdade. Só aceita mensagens com aquela referência exata (*selective receive*). `Partial` é nova e recebe o valor. A cada mensagem, decrementa o contador e acumula.

### `median_ms/2`: cronometragem (linhas 72–82)

```erlang
    Samples = [begin
        Start = erlang:monotonic_time(),
```

`erlang:monotonic_time()` devolve um inteiro que **só cresce**, numa unidade interna da VM (`native`). Ele não serve para saber "que horas são", mas é o certo para medir intervalos. O relógio de sistema (`os:system_time`) pode pular para frente ou para trás se o NTP ajustar a hora, enquanto o monotônico nunca volta.

```erlang
        Result = Fun(),
```

Executa a função que está sendo medida.

```erlang
        Elapsed = erlang:convert_time_unit(erlang:monotonic_time() - Start,
                                           native, microsecond) / 1000,
```

Diferença entre fim e início, convertida da unidade `native` para microssegundos. Dividir por 1000 dá **milissegundos** em float.

```erlang
        {Elapsed, Result}
    end || _ <- lists:seq(1, Repeats)],
```

Repete `Repeats` vezes. O `_` indica que o número da iteração não importa. O resultado é uma lista de tuplas `{tempo, resultado}`.

```erlang
    Sorted = lists:sort([Ms || {Ms, _} <- Samples]),
```

Extrai só os tempos (pattern matching dentro da comprehension) e ordena. Esse `Ms` só existe dentro da comprehension e não tem relação com as variáveis do `main`.

```erlang
    Median = lists:nth((Repeats + 1) div 2, Sorted),
```

Pega o elemento do meio. Com 3 repetições, `(3+1) div 2 = 2`, ou seja, o segundo da lista ordenada. `lists:nth` começa a contar em 1. A mediana é usada em vez da média porque é menos sensível a uma execução atípica (GC, outro programa usando a CPU etc.).

```erlang
    {Median, element(2, hd(Samples))}.
```

Devolve a mediana e o resultado do cálculo. `hd` pega a primeira amostra e `element(2, Tupla)` pega o 2º campo dela. Como o cálculo é determinístico, qualquer amostra serviria.

---

## Alterações em relação à versão original

### Correção: travamento com divisão não exata

Na versão original, a última linha de `parallel_run` era:

```erlang
    collect(Ref, min(Workers, Size), 0).
```

O filtro da list comprehension pode criar **menos** processos que `min(Workers, Size)`, mas o `collect` esperava exatamente essa quantidade de mensagens.

Exemplo: `run(5, 4, _)` dá `Chunk = 2`, e as faixas são 1–2, 3–4 e 5–5. O 4º worker começaria no item 7 e é filtrado. Nasciam 3 processos, mas `collect` esperava 4 respostas, então o programa **travava para sempre**.

Com os valores do `main` (200/800/2000 × 1/2/4/8) a divisão é sempre exata, por isso o bug não aparecia no experimento.

A correção guarda a lista de PIDs devolvida pela comprehension e espera `length(Pids)` respostas, ou seja, exatamente o número de processos criados. Para validar, foram rodadas 49 combinações de divisão não exata (tamanhos 1, 2, 3, 5, 7, 10 e 13 com 1, 2, 3, 4, 5, 8 e 16 workers). Nenhuma travou, e todas deram o mesmo resultado da versão sequencial.

### Organização e legibilidade

- **Seções públicas e privadas:** as funções foram agrupadas pelo que é exportado e pelo que é interno ao módulo.
- **`worker/5` privada:** o processo passou a ser criado com `spawn/1` (função anônima) em vez de `spawn/3`, e `worker/5` saiu do `-export`.
- **`Iterations` no `main`:** o valor `2000`, que aparecia repetido nas duas chamadas ao `run`, virou uma variável junto com os outros parâmetros.
- **Nomes de variáveis no `main`:** `Ms` → `ParMs`, `Result` → `ParResult`, `W` → `Workers` e a lista `Workers` → `WorkerCounts`.

Nenhuma dessas mudanças altera os valores calculados: a coluna `result` do CSV continua a mesma.
