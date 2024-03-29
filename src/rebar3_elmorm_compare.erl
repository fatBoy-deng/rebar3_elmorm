-module(rebar3_elmorm_compare).

-include("elmorm.hrl").

-export([
  foo/0,
  foo2/2,
  svn_file_compare/4
]).

-define(NEWLINE, <<"\n">>).
-define(TAB, <<"    ">>).

-record(elmorm_opts,{
  db_poll,
  db_user_name,
  db_password,
  poll_size,
  db_host,
  db_port,
  encoding,
  compare_file_path,
  output_file_path
}).

-record(svn_elmorm_opts,{
  path,
  username,
  password,
  output_file_path
}).

foo() ->
  compare("./a.kkk", "test.kkk", "./output.sql").

foo2(AppInfo,_State) ->
  Opts = rebar_app_info:opts(AppInfo),
  case read_elmorm_opts(Opts) of
    {ok, RAO} ->
      rebar_api:debug("opts is : ~p", [RAO]),
      #elmorm_opts{
        db_poll = DbPool,
        db_user_name = DbUserName,
        db_password = DbPassword,
        poll_size = PollSize,
        db_host = DbHost,
        db_port = DbPort,
        encoding = Encoding,
        compare_file_path = CompareFilePath,
        output_file_path = OutputFilePath
      } = RAO,
      crypto:start(),
      application:start(emysql),
      _Ret = emysql:add_pool(DbPool, [{size,PollSize}, {user,DbUserName}, {password,DbPassword}, {host,DbHost},
        {port,DbPort}, {database,erlang:atom_to_list(DbPool)}, {encoding, Encoding}]),
      Tables = execute(DbPool,io_lib:format("show tables from ~p",[DbPool])),
      CreateTabBin = get_create_tables_bin(DbPool,Tables,<<>>),
      compare(CreateTabBin,CompareFilePath,OutputFilePath),
      ok;
    {false, _Error} ->
      ok
  end.

read_elmorm_opts(Opts) ->
  case dict:find(elmorm_opts, Opts) of
    {ok, OptsL} ->
      {ok, read_elmorm_opts_1(OptsL, default_opts())};
    error ->
      %% throw ???
      {ok, default_opts()}
  end.

%%-record(elmorm_opts,{
%%  db_poll,
%%  db_user_name,
%%  db_password,
%%  poll_size,
%%  db_host,
%%  db_port,
%%  encoding,
%%  compare_file_path,
%%  output_file_path
%%}).

read_elmorm_opts_1([], R) -> R;
read_elmorm_opts_1([{db_poll, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{db_poll = V});
read_elmorm_opts_1([{db_user_name, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{db_user_name = V});
read_elmorm_opts_1([{db_password, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{db_password = V});
read_elmorm_opts_1([{poll_size, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{poll_size = V});
read_elmorm_opts_1([{db_host, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{db_host = V});
read_elmorm_opts_1([{db_port, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{db_port = V});
read_elmorm_opts_1([{encoding, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{encoding = V});
read_elmorm_opts_1([{compare_file_path, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{compare_file_path = V});
read_elmorm_opts_1([{output_file_path, V} | T], R) ->
  read_elmorm_opts_1(T, R#elmorm_opts{output_file_path = V});
read_elmorm_opts_1([KV | T], R) ->
  rebar_api:error("unknow opts : ~p", [KV]),
  read_elmorm_opts_1(T, R).

default_opts() ->
  #elmorm_opts{}.

svn_file_compare(AppInfo,OldVersion,NewVersion,_State)->
  Opts = rebar_app_info:opts(AppInfo),
  case read_svn_elmorm_opts(Opts) of
    {ok,Opt}  ->
      #svn_elmorm_opts{
        path = Path,
        username = UserName,
        password = PassWord,
        output_file_path = OutPutPath
      }=Opt,
      excute_svn_cmd(OldVersion,Path,UserName,PassWord),
      PathList = string:tokens(Path,"/"),
      FileName1 = hd(lists:reverse(PathList)),
      OldVerFileName = rename_file(FileName1,1),
      excute_svn_cmd(NewVersion,Path,UserName,PassWord),
      NewVerFileName = rename_file(FileName1,2),
      compare(OldVerFileName, NewVerFileName, OutPutPath),
      del_file([OldVerFileName,NewVerFileName]),
      ok;
    _ ->
      ok
  end.

del_file([])->
  ok;
del_file([H|T])->
  file:delete(H),
  del_file(T).

rename_file(FileName,Index)->
  FinFinName = lists:concat([FileName,"_",Index]),
  ok = file:rename(FileName,FinFinName),
  FinFinName.

excute_svn_cmd(Version,Path,UserName,PassWord)->
  Cmd = "svn export -r ~p ~p --no-auth-cache --non-interactive --username ~p --password ~p",
  FinCmd = io_lib:format(Cmd,[Version,Path,UserName,PassWord]),
  os:cmd(FinCmd).

read_svn_elmorm_opts(Opts) ->
  case dict:find(svn_elmorm_opts, Opts) of
    {ok, OptsL} ->
      {ok, read_svn_elmorm_opts_1(OptsL, default_svn_opts())};
    error ->
      %% throw ???
      {ok, default_svn_opts()}
  end.

read_svn_elmorm_opts_1([], R) -> R;
read_svn_elmorm_opts_1([{path, V} | T], R) ->
  read_svn_elmorm_opts_1(T, R#svn_elmorm_opts{path = V});
read_svn_elmorm_opts_1([{username, V} | T], R) ->
  read_svn_elmorm_opts_1(T, R#svn_elmorm_opts{username = V});
read_svn_elmorm_opts_1([{password, V} | T], R) ->
  read_svn_elmorm_opts_1(T, R#svn_elmorm_opts{password = V});
read_svn_elmorm_opts_1([{output_file_path, V} | T], R) ->
  read_svn_elmorm_opts_1(T, R#svn_elmorm_opts{output_file_path = V});
read_svn_elmorm_opts_1([KV | T], R) ->
  rebar_api:error("unknow opts : ~p", [KV]),
  read_svn_elmorm_opts_1(T, R).

default_svn_opts() ->
  #svn_elmorm_opts{}.

get_create_tables_bin(_DBPool,[],Ret)->
  Ret;
get_create_tables_bin(DBPool,[H|T],Bin)->
  TabBin = hd(H),
  CreateTableBinL = execute(DBPool,io_lib:format("show create table ~ts",[TabBin])),
  CreateTableBin = lists:nth(2,hd(CreateTableBinL)),
%%  io:format("CreateTableBin=~p~n",[CreateTableBin]),
  NewBin = <<Bin/binary,CreateTableBin/binary,";">>,
  get_create_tables_bin(DBPool,T,NewBin).

execute(DBPool,Sql) when is_list(Sql) orelse is_binary(Sql) ->
  case emysql:execute(DBPool, Sql) of
    {result_packet, _, _, Rows, _} -> Rows;
    {ok_packet, _, _, UpdatedId, _, _, _} -> UpdatedId;
    {error_packet, _, _, _, Msg} ->
      erlang:error({dbError, {DBPool, Msg, Sql}});
    L when is_list(L) ->
      lists:map(fun
                  ({result_packet, _, _, Rows, _}) -> Rows;
                  ({ok_packet, _, _, UpdatedId, _, _, _}) -> UpdatedId;
                  (_) -> {error, other}
                end, L);
    _Other -> ok
  end.

%% convert file1 to file2, output to file3
compare(File1, File2, File3) when is_list(File1) ->
  case rebar3_elmorm_compile:parse_file(File1) of
    {ok, Tables1} ->
      case rebar3_elmorm_compile:parse_file(File2) of
        {ok, Tables2} ->
          Bin = compare_tables(Tables2, Tables1),
          case file:open(File3, [binary, write]) of
            {ok, IoDevice} ->
              file:write(IoDevice, Bin),
              file:close(IoDevice),
              ok;
            {error, Error} ->
              {error, Error}
          end;
        {error, Error} ->
          {error, Error}
      end;
    {error, Error} ->
      {error, Error}
  end;
compare(Binary, File2, File3) when is_binary(Binary) ->
  case rebar3_elmorm_compile:parse_binary(Binary) of
    {ok, Tables1} ->
      case rebar3_elmorm_compile:parse_file(File2) of
        {ok, Tables2} ->
          Bin = compare_tables(Tables2, Tables1),
          case file:open(File3, [binary, write]) of
            {ok, IoDevice} ->
              file:write(IoDevice, Bin),
              file:close(IoDevice),
              ok;
            {error, Error} ->
              {error, Error}
          end;
        {error, Error} ->
          {error, Error}
      end;
    {error, Error} ->
      {error, Error}
  end.

compare_tables(TablesA, TablesB) ->
  compare_tables(TablesA, TablesB, []).
compare_tables([], TablesB, R) ->
  lists:reverse(lists:foldl(fun(X, InAcc) ->
    [?NEWLINE, ?NEWLINE, drop_table(X#elm_table.name) | InAcc]
                            end, R, TablesB));
compare_tables([H | T], TablesB, R) ->
  case lists:keytake(H#elm_table.name, #elm_table.name, TablesB) of
    {value, Tuple, Rest} ->
      case table_diff(Tuple, H) of
        <<>> ->
          compare_tables(T, Rest, R);
        Diff ->
          compare_tables(T, Rest, [?NEWLINE, ?NEWLINE, Diff | R])
      end;
    false ->
      compare_tables(T, TablesB, [?NEWLINE, ?NEWLINE, create_table(H) | R])
  end.

drop_table(Name) ->
  iolist_to_binary([<<"DROP TABLE `">>, Name, <<"`;">>]).

table_diff(TableA, TableB) ->
  TName = TableA#elm_table.name,
  ALTER = <<"ALTER TABLE `", TName/binary, "` ">>,
  {ok, DiffMap} = rebar3_elmorm_diff:diff(TableA, TableB),
  #{
    table_opt_diff := TableOptDiff,
    col_remove := ColDrops,
    col_add := ColAdds,
    col_modify := ColModifys,
    prikey_remove := PriKeyRemove,
    prikey_add := PriKeyAdd,
    idx_remove := IdxRemove,
    idx_add := IdxAdd
  } = DiffMap,
  L0 = build_table_options(ALTER, TableOptDiff),
  L1 = [<<ALTER/binary, "DROP COLUMN `", (X#elm_field.name)/binary, "`;">> || X <- ColDrops],
  L2 = [<<ALTER/binary, "ADD COLUMN ", (format_table_field(X, true))/binary, ";">> || X <- ColAdds],
  L3 = [<<ALTER/binary, "MODIFY COLUMN ", (format_table_field(X, true))/binary, ";">> || X <- ColModifys],
  L4 = [<<ALTER/binary, "DROP PRIMARY KEY;">> || _ <- PriKeyRemove],
  L5 = [<<ALTER/binary, "ADD PRIMARY KEY ", (format_key_parts(X#elm_index.fields))/binary, ";">> || X <- PriKeyAdd],
  L6 = [<<ALTER/binary, "DROP INDEX `", (X#elm_index.name)/binary, "`;">> || X <- IdxRemove],
  L7 = [<<ALTER/binary, "ADD ", (format_table_index(X))/binary, ";">> || X <- IdxAdd],
  L = lists:foldl(fun(Y, InAcc) ->
    Y ++ InAcc
                  end, [], [L7, L6, L5, L4, L3, L2, L1, L0]),
  connact_table_diff(L).
connact_table_diff(L) ->
  connact_table_diff(L, <<>>).
connact_table_diff([], Bin) -> Bin;
connact_table_diff([H], Bin) ->
  connact_table_diff([], <<Bin/binary, H/binary>>);
connact_table_diff([H | T], Bin) ->
  connact_table_diff(T, <<Bin/binary, H/binary, ?NEWLINE/binary>>).

build_table_options(ALTER, TableOptDiff) ->
  case build_table_options(?TABLE_OPTS_SEQ, TableOptDiff, <<>>) of
    <<>> -> [];
    Diff ->
      [<<ALTER/binary, Diff/binary, ";">>]
  end.

build_table_options([], _TOD, R) -> R;
build_table_options([H | T], TOD, <<>>) ->
  case maps:get(H, TOD, undefined) of
    undefined -> build_table_options(T, TOD, <<>>);
    Value ->
      build_table_options(T, TOD, <<(format_table_option(H, Value))/binary>>)
  end;
build_table_options([H | T], TOD, R) ->
  case maps:get(H, TOD, undefined) of
    undefined -> build_table_options(T, TOD, R);
    Value ->
      build_table_options(T, TOD, <<R/binary, ",", (format_table_option(H, Value))/binary>>)
  end.

create_table(Table) ->
  Fields = format_table_fields(Table#elm_table.fields),
  PrimaryKey = format_table_pri_key(Table#elm_table.primary_key),
  Index = format_table_indexs(Table#elm_table.index),
  TableDefine = format_table_define(Fields ++ (PrimaryKey ++ Index)),
  %% Index = <<>>,
  TableOpts = format_table_opts(Table#elm_table.options),
  iolist_to_binary([
    <<"CREATE TABLE `">>, Table#elm_table.name, <<"` (">>, TableDefine,
    ?NEWLINE, <<")">>, TableOpts, <<";">>
  ]).

%% begin of fields
format_table_fields(Fields) ->
  format_table_fields(Fields, []).
format_table_fields([], R) -> lists:reverse(R);
format_table_fields([H | T], R) ->
  format_table_fields(T, [format_table_field(H, false) | R]).


format_table_field(Field, true) ->
  iolist_to_binary([
    "`", Field#elm_field.name, "` ", format_type(Field),
    format_column_options(Field#elm_field.options),
    format_column_seq(Field#elm_field.pre_col_name)

  ]);
format_table_field(Field, false) ->
  iolist_to_binary([
    "`", Field#elm_field.name, "` ", format_type(Field),
    format_column_options(Field#elm_field.options)
  ]).

format_type(Field) ->
  L0 =
    case is_list(Field#elm_field.charset) of
      true -> [<<" CHARACTER SET ">>, Field#elm_field.charset];
      false -> []
    end,
  L1 =
    case Field#elm_field.is_signed of
      undefined -> L0;
      true -> [<<" SIGNED">> | L0];
      false -> [<<" UNSIGNED">> | L0]
    end,
  L2 =
    case is_integer(Field#elm_field.data_len) of
      true -> ["(", erlang:integer_to_binary(Field#elm_field.data_len), ")" | L1];
      false -> L1
    end,
  iolist_to_binary([erlang:atom_to_binary(Field#elm_field.data_type, utf8) | L2]).

format_column_options(Options) ->
  iolist_to_binary(format_column_options(?COLUMN_OPTS_SEQ, Options, [])).

format_column_options([], _Options, R) -> lists:reverse(R);
format_column_options([auto_increment | T], Options, R) ->
  case maps:get(auto_increment, Options) of
    undefined -> format_column_options(T, Options, R);
    true ->
      NewR = [<<" ", (maps:get(auto_increment, ?COLUMN_OPTS_SNAME))/binary>> | R],
      format_column_options(T, Options, NewR)
  end;
format_column_options([null | T], Options, R) ->
  case maps:get(null, Options) of
    undefined -> format_column_options(T, Options, R);
    true ->
      NewR = [<<" ", (maps:get(null, ?COLUMN_OPTS_SNAME))/binary>> | R],
      format_column_options(T, Options, NewR);
    false ->
      NewR = [<<" NOT ", (maps:get(null, ?COLUMN_OPTS_SNAME))/binary>> | R],
      format_column_options(T, Options, NewR)
  end;
format_column_options([OptName | T], Options, R) ->
  case maps:get(OptName, Options) of
    undefined -> format_column_options(T, Options, R);
    Value ->
      NewR = [iolist_to_binary([" ", maps:get(OptName, ?COLUMN_OPTS_SNAME), " ", format_option_value(Value)]) | R],
      format_column_options(T, Options, NewR)
  end.

format_column_seq(undefined) -> <<" FIRST">>;
format_column_seq(Name) -> <<" AFTER `", Name/binary, "`">>.
%% end of fields


%% begin of primary key
format_table_pri_key([]) -> [];
format_table_pri_key([H]) ->
  [iolist_to_binary([<<"PRIMARY KEY ">>, format_key_parts(H#elm_index.fields)])].

format_key_parts(IFields) ->
  iolist_to_binary(["(", format_key_parts(IFields, []), ")"]).
format_key_parts([], R) -> lists:reverse(R);
format_key_parts([H], R) ->
  L0 =
    case H#elm_index_field.sort of
      undefined -> [];
      Other -> [" ", Other]
    end,
  L1 =
    case H#elm_index_field.len of
      undefined -> L0;
      Len -> ["(", erlang:integer_to_binary(Len), ")" | L0]
    end,
  format_key_parts([], [iolist_to_binary(["`", H#elm_index_field.col_name, "`" | L1]) | R]);
format_key_parts([H | T], R) ->
  L0 = [", "],
  L1 =
    case H#elm_index_field.sort of
      undefined -> L0;
      Other -> [" ", Other | L0]
    end,
  L2 =
    case H#elm_index_field.len of
      undefined -> L1;
      Len -> ["(", erlang:integer_to_binary(Len), ")" | L1]
    end,
  format_key_parts(T, [iolist_to_binary(["`", H#elm_index_field.col_name, "`" | L2]) | R]).

%% end of primary key


%% begin of index
format_table_indexs(Index) ->
  format_table_indexs(Index, []).
format_table_indexs([], R) -> lists:reverse(R);
format_table_indexs([H | T], R) ->
  format_table_indexs(T, [format_table_index(H) | R]).
format_table_index(#elm_index{class = normal} = H) ->
  L0 = [" ", format_key_parts(H#elm_index.fields)],
  L1 =
    case H#elm_index.index_type of
      undefined -> L0;
      IndexType -> [" ", "USING ", IndexType | L0]
    end,
  L2 =
    case H#elm_index.name of
      undefined -> L1;
      IndexName -> [" `", IndexName, "`" | L1]
    end,
  iolist_to_binary(["INDEX" | L2]);
format_table_index(#elm_index{class = unique} = H) ->
  L0 = [" ", format_key_parts(H#elm_index.fields)],
  L1 =
    case H#elm_index.index_type of
      undefined -> L0;
      IndexType -> [" ", "USING ", IndexType | L0]
    end,
  L2 =
    case H#elm_index.name of
      undefined -> L1;
      IndexName -> [" `", IndexName, "`" | L1]
    end,
  iolist_to_binary(["UNIQUE KEY" | L2]).
%% end of index

%% begin of table define
format_table_define(TableDefines) ->
  iolist_to_binary(format_table_define(TableDefines, [])).
format_table_define([], R) -> lists:reverse(R);
format_table_define([H], R) ->
  format_table_define([], [iolist_to_binary([?NEWLINE, ?TAB, H]) | R]);
format_table_define([H | T], R) ->
  format_table_define(T, [iolist_to_binary([?NEWLINE, ?TAB, H, <<",">>]) | R]).
%% end of table define

%% begin of table options
format_table_opts(Options) ->
  iolist_to_binary(format_table_opts(?TABLE_OPTS_SEQ, Options, [])).

format_table_opts([], _Options, R) -> lists:reverse(R);
format_table_opts([OptName | T], Options, R) ->
  case maps:get(OptName, Options) of
    undefined ->
      format_table_opts(T, Options, R);
    Value ->
      NewR = [iolist_to_binary([" ", format_table_option(OptName, Value)]) | R],
      format_table_opts(T, Options, NewR)
  end.

format_table_option(OptName, Value) ->
  <<(maps:get(OptName, ?TABLE_OPTS_SNAME))/binary, "=", (format_option_value(Value))/binary>>.

format_option_value(null) ->
  <<"NULL">>;
format_option_value(V) when is_binary(V) ->
  <<"'", V/binary, "'">>;
format_option_value(V) when is_list(V) ->
  unicode:characters_to_binary(V);
format_option_value(V) when is_integer(V) ->
  erlang:integer_to_binary(V).
%% end of table options