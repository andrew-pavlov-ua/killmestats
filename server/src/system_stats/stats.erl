-module(stats).

-export([cpu_load/0, ram_load/0, snapshot/0]).

%% Return a snapshot as percentages in the 0.0..100.0 range.
%% Add future metrics (disk, network, temperatures, and so on) to `extra`
%% without changing the existing CPU and RAM fields.
snapshot() ->
    #{
        cpu_load => cpu_load(),
        ram_load => ram_load(),
        extra => #{}
    }.

cpu_load() ->
    ensure_os_mon_started(),
    try cpu_sup:util() of
        Value when is_number(Value) -> clamp(float(Value));
        _ -> 0.0
    catch
        _Class:_Reason -> 0.0
    end.

% This one gets incorrect amount of storage (90% when it's actually 50%, because of cached "free" memory)
% ram_load() ->
%     ensure_os_mon_started(),
%     try memsup:get_memory_data() of
%         {Total, Allocated, _Worst}
%             when is_number(Total), Total > 0, is_number(Allocated) ->
%             clamp(Allocated / Total * 100.0);
%         _ ->
%             0.0
%     catch
%         _Class:_Reason -> 0.0
%     end.

ram_load() ->
    ensure_os_mon_started(),
    MemData = memsup:get_system_memory_data(),

    Total = proplists:get_value(total_memory, MemData, 1),
    Available = proplists:get_value(available_memory, MemData, 1),

    RamLoad = (Total - Available) / Total * 100,

%     % Another way of counting Allocated Ram
%     % Free = proplists:get_value(free_memory, MemData, 0),
%     % Cached = proplists:get_value(cached_memory, MemData, 0),
%     % Buffered = proplists:get_value(buffered_memory, MemData, 0),
%     % Total = proplists:get_value(total_memory, MemData, 0),
%     % RamLoad = (Free + Cached + Buffered) / Total * 100,

    clamp(RamLoad).

ensure_os_mon_started() ->
    _ = application:ensure_all_started(os_mon),
    ok.

clamp(Value) when Value < 0.0 -> 0.0;
clamp(Value) when Value > 100.0 -> 100.0;
clamp(Value) -> Value.
