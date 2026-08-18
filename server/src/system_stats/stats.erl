-module(stats).

-export([cpu_load/0, memory_stats/0]).

cpu_load() ->
      case application:ensure_all_started(os_mon) of
          {ok, _Started} ->
             read_cpu_load();
             {error, Reason} ->
            logger:error(
                 "Failed to start os_mon: ~p",
              [Reason]
             ),
             0.0
     end.

read_cpu_load() ->
    try cpu_sup:util() of
      Value when is_number(Value) ->
          clamp(float(Value));
      Unexpected ->
          logger:error(
              "cpu_sup:util() returned unexpected value: ~p",
              [Unexpected]
          ),
          0.0
    catch
      Class:Reason:Stacktrace ->
          logger:error(
              "cpu_sup:util() failed; class=~p reason=~p stacktrace=~p",
              [Class, Reason, Stacktrace]
          ),
          0.0
    end.

memory_stats() ->
    ensure_os_mon_started(),
    MemData = memsup:get_system_memory_data(),

    %% Available memory keeps filesystem cache from being reported as pressure.
    Total = proplists:get_value(total_memory, MemData, 1),
    Available = proplists:get_value(available_memory, MemData, 1),
    Used = max(Total - Available, 0),

    {clamp(Used / Total * 100), Used, Total}.

ensure_os_mon_started() ->
    _ = application:ensure_all_started(os_mon),
    ok.

clamp(Value) when Value < 0.0 -> 0.0;
clamp(Value) when Value > 100.0 -> 100.0;
clamp(Value) -> Value.
