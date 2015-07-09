%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2015 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_queue_master_location_misc).

-include("rabbit.hrl").

-export([lookup_master/2,
         lookup_queue/2,
         get_location/1,
         get_location_by_config/1,
         get_location_by_args/1,
         get_location_by_policy/1,
         all_nodes/0]).

lookup_master(QueueNameBin, VHostPath) when is_binary(QueueNameBin),
                                            is_binary(VHostPath) ->
    Queue = rabbit_misc:r(VHostPath, queue, QueueNameBin),
    case rabbit_amqqueue:lookup(Queue) of
        {ok, #amqqueue{pid=Pid}} when is_pid(Pid) -> 
            {ok, node(Pid)};
        Error -> Error
    end.

lookup_queue(QueueNameBin, VHostPath) when is_binary(QueueNameBin),
                                           is_binary(VHostPath) ->
    Queue = rabbit_misc:r(VHostPath, queue, QueueNameBin),
    case rabbit_amqqueue:lookup(Queue) of
        Reply = {ok, #amqqueue{}} -> Reply;
        Error                     -> Error
    end.

get_location(Queue=#amqqueue{})->
    case get_location_by_args(Queue) of
        _Err1={error, _} ->
            case get_location_by_policy(Queue) of
                _Err2={error, _} ->
                    case get_location_by_config(Queue) of
                        Err3={error, _}   -> Err3;
                        Reply={ok, _Node} -> Reply
                    end;
                Reply={ok, _Node} -> Reply
            end;
        Reply={ok, _Node} -> Reply
    end.

get_location_by_args(Queue=#amqqueue{arguments=Args}) ->
    case proplists:lookup(<<"queue-master-location">> , Args) of
        {<<"queue-master-location">> , Strategy}  ->
            case rabbit_queue_location_validator:validate_strategy(Strategy) of
                {ok, CB} -> CB:queue_master_location(Queue);
                Error    -> Error
            end;
        _ -> {error, "queue-master-location undefined"}
    end.

get_location_by_policy(Queue=#amqqueue{}) ->
    case rabbit_policy:get(<<"queue-master-location">> , Queue) of
        undefined ->  {error, "queue-master-location policy undefined"};
        Strategy  ->
            case rabbit_queue_location_validator:validate_strategy(Strategy) of
                {ok, CB} -> CB:queue_master_location(Queue);
                Error    -> Error
            end
    end.

get_location_by_config(Queue=#amqqueue{}) ->
    case application:get_env(rabbit, queue_master_location) of
        {ok, Strategy} ->
            case rabbit_queue_location_validator:validate_strategy(Strategy) of
                {ok, CB} -> CB:queue_master_location(Queue);
                Error    -> Error
            end;
        _ -> {error, "queue-master-location undefined"}
    end.

all_nodes()  -> rabbit_mnesia:cluster_nodes(running).
