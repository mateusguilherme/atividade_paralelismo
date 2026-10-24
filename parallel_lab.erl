-module(parallel_lab).
-export([main/0, run/3]).

%%====================================================================
%% Public functions
%%====================================================================

main() ->
    Sizes = [200, 800, 2000],
    WorkerCounts = [1, 2, 4, 8],
    Repeats = 3,
    Iterations = 2000,
    io:format("size,workers,median_ms,speedup,efficiency,result~n"),
    lists:foreach(fun(Size) ->
        {SeqMs, SeqResult} = median_ms(fun() -> run(Size, 1, Iterations) end, Repeats),
        lists:foreach(fun(Workers) ->
            {ParMs, ParResult} = case Workers of
                1 -> {SeqMs, SeqResult};
                _ -> median_ms(fun() -> run(Size, Workers, Iterations) end, Repeats)
            end,
            Speedup = SeqMs / ParMs,
            Efficiency = Speedup / Workers,
            io:format("~B,~B,~.3f,~.4f,~.4f,~B~n",
                      [Size, Workers, ParMs, Speedup, Efficiency, ParResult]),
            case ParResult =:= SeqResult of
                true -> ok;
                false -> erlang:error({incorrect_result, Size, Workers})
            end
        end, WorkerCounts)
    end, Sizes).

run(Size, Workers, Iterations) when Size > 0, Workers > 0 ->
    case Workers of
        1 -> chunk_sum(1, Size, Iterations, 0);
        _ -> parallel_run(Size, Workers, Iterations)
    end.

%%====================================================================
%% Private functions
%%====================================================================

parallel_run(Size, Workers, Iterations) ->
    Parent = self(),
    Chunk = (Size + Workers - 1) div Workers,
    Ref = make_ref(),
    Pids = [begin
        Start = ((Index - 1) * Chunk) + 1,
        Stop = min(Index * Chunk, Size),
        spawn(fun() -> worker(Parent, Ref, Start, Stop, Iterations) end)
    end || Index <- lists:seq(1, Workers), ((Index - 1) * Chunk) < Size],
    collect(Ref, length(Pids), 0).

worker(Parent, Ref, Start, Stop, Iterations) ->
    Sum = chunk_sum(Start, Stop, Iterations, 0),
    Parent ! {partial, Ref, Sum}.

chunk_sum(Current, Stop, _Iterations, Acc) when Current > Stop -> Acc;
chunk_sum(Current, Stop, Iterations, Acc) ->
    chunk_sum(Current + 1, Stop, Iterations,
              Acc + item_work(Current, Iterations)).

item_work(Seed, Iterations) -> work_loop(Iterations, Seed rem 1000003).
work_loop(0, Value) -> Value;
work_loop(N, Value) -> work_loop(N - 1, (Value * 48271 + 1) rem 2147483647).

collect(_Ref, 0, Sum) -> Sum;
collect(Ref, Remaining, Sum) ->
    receive
        {partial, Ref, Partial} -> collect(Ref, Remaining - 1, Sum + Partial)
    end.

median_ms(Fun, Repeats) ->
    Samples = [begin
        Start = erlang:monotonic_time(),
        Result = Fun(),
        Elapsed = erlang:convert_time_unit(erlang:monotonic_time() - Start,
                                           native, microsecond) / 1000,
        {Elapsed, Result}
    end || _ <- lists:seq(1, Repeats)],
    Sorted = lists:sort([Ms || {Ms, _} <- Samples]),
    Median = lists:nth((Repeats + 1) div 2, Sorted),
    {Median, element(2, hd(Samples))}.
