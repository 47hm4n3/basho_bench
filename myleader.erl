-module(myleader).

-behaviour(supervisor).

-include("basho_bench.hrl").

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% Config params
-record(state, {  keygen,              %%worker
                  valgen,
                  driver,
                  shutdown_on_error,
                  rng_seed,
                  ops,
                  mode,
                  concurrent,          %%sup
                  measurement_driver,
                  log_level,
                  c_log_level           %%b_b
                  pre_hook,
                  post_hook,
                  code_paths,
                  source_dir,
                  antidote_pb_ips,    %%driver
                  antidote_pb_port,
                  antidote_types,
                  set_size,
                  num_updates,
                  num_reads,
                  staleness }).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
	io:fwrite("hello from myleader:start_link\n"),
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


start() ->
ok = mygenserv:launchWorkersSup(),
io:fwrite("hello from leader:start 1\n"),
ok = application:set_env(basho_bench_app, is_running, true),
io:fwrite("hello from leader:start 2\n"),
ok = basho_bench_stats:run(),
io:fwrite("hello from leader:start 3\n"),
ok = basho_bench_measurement:run(),
io:fwrite("hello from leader:start 4\n"),
ok = mygenserv:launchWorkers().

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
	io:fwrite("hello from myleader:init\n"),
  
  %Worker params
    %%rng_seed if dispo
    %%driver 
    %%shutdown_on_error
    %%key_generator
    %%value_generator
    %%ops
    %%mode max, {rate, max}, {rate, Rate}
    RngSeed =
      case basho_bench_config:get(rng_seed, {42, 23, 12}) of
            {Aa, Ab, Ac} -> {Aa, Ab, Ac};
            now -> now() %% je ne sais pas si c'est a sa place lol
       end,
    Driver  = basho_bench_config:get(driver),
    ShutdownOnError = basho_bench_config:get(shutdown_on_error, false),
    Mode    = basho_bench_config:get(mode), 
    KeyGen = basho_bench_config:get(key_generator),
    ValGen = basho_bench_config:get(value_generator),
    Ops = ops_tuple(),


  %sup params
    %%concurrent
    %%measurement_driver
    Concurrent= basho_bench_config:get(concurrent),
    MeasurementDriver = basho_bench_config:get(measurement_driver, undefined),

  %b_b params
    %%log_level
    %%key_generator
    %%value_generator
    %%pre_hook
    %%post_hook
    %%code_paths
    %%source_dir
    ConsoleLagerLevel = basho_bench_config:get(log_level, debug),
    CustomLagerLevel = basho_bench_config:get(log_level),
    PreHook = basho_bench_config:get(pre_hook, no_op),
    PostHook = basho_bench_config:get(post_hook, no_op),
    CodePaths = basho_bench_config:get(code_paths, []),
    SourceDir = basho_bench_config:get(source_dir, []),

  %driver params
    %%antidote_pb_ips
    %%antidote_pb_port
    %%antidote_types
    %%set_size
    %%num_updates
    %%num_reads
    %%staleness
    IPs = basho_bench_config:get(antidote_pb_ips),
    PbPort = basho_bench_config:get(antidote_pb_port),
    Types  = basho_bench_config:get(antidote_types),
    SetSize = basho_bench_config:get(set_size),
    NumUpdates  = basho_bench_config:get(num_updates),
    NumReads = basho_bench_config:get(num_reads),
    MeasureStaleness = basho_bench_config:get(staleness),

  State = #state {  keygen = KeyGen,
                    valgen = ValGen,
                    driver = Driver,
                    shutdown_on_error = ShutdownOnError,
                    rng_seed = RngSeed,
                    ops = Ops,
                    mode = Mode,
                    concurrent = Concurrent,
                    measurement_driver = MeasurementDriver, 
                    log_level = ConsoleLagerLevel,
                    pre_hook = PreHook,
                    post_hook = PostHook,
                    code_paths = CodePaths,
                    source_dir = SourceDir,
                    antidote_pb_ips = IPs,
                    antidote_pb_port = PbPort,
                    antidote_types = Types,
                    set_size = SetSize,
                    num_updates = NumUpdates,
                    num_reads = NumReads,
                    staleness = MeasureStaleness },

io:fwrite("hello from myleader:init --> ~s \n", driver),

   {ok,                   % ok, supervisor here's what we want you to do
  {                       
    {                     % Global supervisor options
      one_for_one,        % - use the one-for-one restart strategy
      1000,               % - and allow a maximum of 1000 restarts
      3600                % - per hour for each child process
    },                     
    [                     % The list of child processes you should supervise
      {                   % We only have one
        mygenserv,     	  % - Register it under the name mygenserv
        {                 % - Here's how to find and start this child's code 
          mygenserv,   	  %   * the module is called mygenserv
          start_link,     %   * the function to invoke is called start_link
          []              %   * and here's the list of default parameters to use
        },                
        permanent,        % - child should run permantenly, restart on crash 
        2000,             % - give child 2 sec to clean up on system stop, then kill 
        worker,           % - FYI, this child is a worker, not a supervisor
        [mygenserv]    	  % - these are the modules the process uses  
      } 
    ]                     
  }                        
}. 

%%
%% Expand operations list into tuple suitable for weighted, random draw
%%
ops_tuple() ->
    F =
        fun({OpTag, Count}) ->
                lists:duplicate(Count, {OpTag, OpTag});
           ({Label, OpTag, Count}) ->
                lists:duplicate(Count, {Label, OpTag})
        end,
    Ops = [F(X) || X <- basho_bench_config:get(operations, [])],
    list_to_tuple(lists:flatten(Ops)).