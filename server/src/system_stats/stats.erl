-module(stats).

-export([cpu_load/0, memory_stats/0]).

cpu_load() ->
    ensure_os_mon_started(),
    try cpu_sup:util() of
        Value when is_number(Value) -> clamp(float(Value));
        _ -> 0.0
    catch
        _Class:_Reason -> 0.0
    end.

memory_stats() ->
    ensure_os_mon_started(),
    MemData = memsup:get_system_memory_data(),

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
