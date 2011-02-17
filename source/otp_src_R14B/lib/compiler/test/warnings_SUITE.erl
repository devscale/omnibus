%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2003-2010. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%
%%
-module(warnings_SUITE).

%%-define(STANDALONE, true).

-ifdef(STANDALONE).
-define(line, put(line, ?LINE), ).
-define(config(X,Y), foo).
-define(privdir, "warnings_SUITE_priv").
-define(t, test_server).
-else.
-include("test_server.hrl").
-define(datadir, ?config(data_dir, Conf)).
-define(privdir, ?config(priv_dir, Conf)).
-endif.

-export([all/1,init_per_testcase/2,fin_per_testcase/2]).

-export([pattern/1,pattern2/1,pattern3/1,pattern4/1,
	 guard/1,bad_arith/1,bool_cases/1,bad_apply/1,
         files/1,effect/1,bin_opt_info/1,bin_construction/1]).

% Default timetrap timeout (set in init_per_testcase).
-define(default_timeout, ?t:minutes(2)).

init_per_testcase(_Case, Config) ->
    ?line Dog = ?t:timetrap(?default_timeout),
    [{watchdog, Dog} | Config].

fin_per_testcase(_Case, Config) ->
    Dog = ?config(watchdog, Config),
    test_server:timetrap_cancel(Dog),
    ok.

all(suite) ->
    test_lib:recompile(?MODULE),
    [pattern,pattern2,pattern3,pattern4,
     guard,bad_arith,bool_cases,bad_apply,files,effect,
     bin_opt_info,bin_construction].

pattern(Config) when is_list(Config) ->
    %% Test warnings generated by v3_core.
    Ts = [{pattern,
           <<"%% Just a comment here.
              f(a={glurf,2}=A) -> A.

              g(A) ->
                 case A of
                   a=[_|_] -> error;
                   Other -> true
                 end.

              foo(X) ->
                 a = {nisse,b} = X.
           ">>,
	   [warn_unused_vars],
	   {warnings,
	    [{2,v3_core,nomatch},
	     {6,v3_core,nomatch},
	     {11,v3_core,nomatch} ] }}],
    ?line [] = run(Config, Ts),
    ok.

pattern2(Config) when is_list(Config) ->
    %% Test warnings generated by sys_core_fold.
    %% If we disable Core Erlang optimizations, we expect that
    %% v3_kernel should generate some of the warnings.
    Source = <<"f(A) -> ok;
              f(B) -> error.
	      t(A, B, C) ->
	        case {A,B,C} of
	          {a,B} -> ok;
	          {_,B} -> ok
                end.
           ">>,

    %% Test warnings from sys_core_fold.
    Ts = [{pattern2,
	   Source,
	   [nowarn_unused_vars],
	   {warnings,[{2,sys_core_fold,{nomatch_shadow,1}},
		      {5,sys_core_fold,nomatch_clause_type},
		      {6,sys_core_fold,nomatch_clause_type}]}}],
    ?line [] = run(Config, Ts),

    %% Disable Core Erlang optimizations. v3_kernel should produce
    %% a warning for the clause that didn't match.
    Ts2 = [{pattern2,
	    Source,
	    [nowarn_unused_vars,no_copt],
	    {warnings,
	     [{2,v3_kernel,{nomatch_shadow,1}}]}}],
    ?line [] = run(Config, Ts2),
    ok.

pattern3(Config) when is_list(Config) ->
    %% Test warnings generated by the pattern matching compiler
    %% in v3_kernel.

    Ts = [{pattern3,
	   <<"
	    f({A,_}) -> {ok,A};
	    f([_|_]=B) -> {ok,B};
	    f({urk,nisse}) -> urka_glurka.
           ">>,
	   [nowarn_unused_vars],
	   {warnings,
	    [{4,v3_kernel,{nomatch_shadow,2}}]}}],
    ?line [] = run(Config, Ts),

    ok.

pattern4(Config) when is_list(Config) ->
    %% Test warnings for clauses that cannot possibly match.

    Ts = [{pattern4,
	   <<"
             t() ->
               case true of 
                 false -> a;
                 true -> b
               end.

             fi() ->
               case true of 
                 false -> a;
                 false -> b
               end,
               case true of 
                 true -> a;
                 true -> b;
                 X -> X
               end,
               case boolean of 
                 true -> a;
                 false -> b
               end.
             int() ->
               case 42 of
                 [a|b] -> no;
                 <<1>> -> no;
                 <<X>> -> no;
                 17 -> no;
                 [] -> no;
                 a -> no;
                 {a,b,c} -> no
               end.
             tuple() ->
               case {x,y,z} of
                 \"xyz\" -> no;
                 [a|b] -> no;
                 <<1>> -> no;
                 <<X>> -> no;
                 17 -> no;
                 [] -> no;
                 a -> no;
                 {a,b,c} -> no;
                 {x,y} -> no
               end.
           ">>,
	   [nowarn_unused_vars],
	   {warnings,
	    [{9,sys_core_fold,no_clause_match},
	     {18,sys_core_fold,no_clause_match},
	     {23,sys_core_fold,no_clause_match},
	     {33,sys_core_fold,no_clause_match}
	    ]}}],
    ?line [] = run(Config, Ts),

    ok.

guard(Config) when is_list(Config) ->
    %% Test warnings for false guards.

    Ts = [{guard,
	   <<"
              t(A, B) when element(x, dum) -> ok.

              tt(A, B) when 1 == 2 -> ok.

              ttt() when element(x, dum) -> ok.

              t4(T, F) when element({F}, T) -> ok.
              t5(T, F) when element([F], T) -> ok.
              t6(Pos, F) when element(Pos, [F]) -> ok.
              t7(Pos) when element(Pos, []) -> ok.
           ">>,
	   [nowarn_unused_vars],
	   {warnings,
	    [{2,sys_core_fold,no_clause_match},
	     {2,sys_core_fold,nomatch_guard},
	     {2,sys_core_fold,{eval_failure,badarg}},
	     {4,sys_core_fold,no_clause_match},
	     {4,sys_core_fold,nomatch_guard},
	     {6,sys_core_fold,no_clause_match},
	     {6,sys_core_fold,nomatch_guard},
	     {6,sys_core_fold,{eval_failure,badarg}},
	     {8,sys_core_fold,no_clause_match},
	     {8,sys_core_fold,nomatch_guard},
	     {8,sys_core_fold,{eval_failure,badarg}},
	     {9,sys_core_fold,no_clause_match},
	     {9,sys_core_fold,nomatch_guard},
	     {9,sys_core_fold,{eval_failure,badarg}},
	     {10,sys_core_fold,no_clause_match},
	     {10,sys_core_fold,nomatch_guard},
	     {10,sys_core_fold,{eval_failure,badarg}},
	     {11,sys_core_fold,no_clause_match},
	     {11,sys_core_fold,nomatch_guard},
	     {11,sys_core_fold,{eval_failure,badarg}}
	    ]}}],
    ?line [] = run(Config, Ts),

    ok.

bad_arith(Config) when is_list(Config) ->
    Ts = [{bad_arith,
           <<"f() ->
                if
                  a + 3 > 3 -> ok;
          	 true -> error
              end.

              g(A) ->
                if
                  is_integer(A), a + 3 > 3 -> ok;
                  a + 3 > 42, is_integer(A) -> ok;
          	 true -> error
              end.

              h(A) ->
                a + 3 + A.
           ">>,
	   [],
	   {warnings,
	    [{3,sys_core_fold,nomatch_guard},
	     {3,sys_core_fold,{eval_failure,badarith}},
	     {9,sys_core_fold,nomatch_guard},
	     {9,sys_core_fold,{eval_failure,badarith}},
	     {10,sys_core_fold,nomatch_guard},
	     {10,sys_core_fold,{eval_failure,badarith}},
	     {15,sys_core_fold,{eval_failure,badarith}}
	    ] }}],
    ?line [] = run(Config, Ts),
    ok.

bool_cases(Config) when is_list(Config) ->
    Ts = [{bool_cases,
	   <<"
            f(A, B) ->
               case A > B of
                 true -> true;
                 false -> false;
                 Other -> {error,not_bool}
               end.

            g(A, B) ->
               case A =/= B of
                 false -> false;
                 true -> true;
                 Other -> {error,not_bool}
               end.

	    h(Bool) ->
              case not Bool of
	        maybe -> strange;
	        false -> ok;
	        true -> error
            end.
           ">>,
	   [nowarn_unused_vars],
	   {warnings,
	    [{6,sys_core_fold,nomatch_shadow},
	     {13,sys_core_fold,nomatch_shadow},
	     {18,sys_core_fold,nomatch_clause_type} ]} }],
    ?line [] = run(Config, Ts),
    ok.

bad_apply(Config) when is_list(Config) ->
    Ts = [{bad_apply,
	   <<"
             t(1) -> 42:42();
             t(2) -> erlang:42();
             t(3) -> 42:start();
             t(4) -> []:start();
             t(5) -> erlang:[]().
           ">>,
	   [],
	   {warnings,
	    [{2,v3_kernel,bad_call},
	     {3,v3_kernel,bad_call},
	     {4,v3_kernel,bad_call},
	     {5,v3_kernel,bad_call},
	     {6,v3_kernel,bad_call}]}}],
    ?line [] = run(Config, Ts),

    %% Also verify that the generated code generates the correct error.
    ?line try erlang:42() of
	      _ -> ?line ?t:fail()
	  catch
	      error:badarg -> ok
	  end,
    ok.

files(Config) when is_list(Config) ->
    Ts = [{files_1,
	   <<"
              -file(\"file1\", 14).

              t1() ->
                  1/0.

              -file(\"file2\", 7).

              t2() ->
                  1/0.
           ">>,
           [],
           {warnings,
            [{"file1",[{17,sys_core_fold,{eval_failure,badarith}}]},
             {"file2",[{10,sys_core_fold,{eval_failure,badarith}}]}]}}],

    ?line [] = run(Config, Ts),
    ok.

%% Test warnings for term construction and BIF calls in effect context.
effect(Config) when is_list(Config) ->
    Ts = [{lc,
	   <<"
             t(X) ->
               case X of
              	warn_lc ->
              	    [is_integer(Z) || Z <- [1,2,3]];
              	warn_lc_2 ->
              	    [{error,Z} || Z <- [1,2,3]];
              	warn_lc_3 ->
              	    [{error,abs(Z)} || Z <- [1,2,3]];
              	no_warn_lc ->
              	    [put(last_integer, Z) || Z <- [1,2,3]]; %no warning
              	unused_tuple_literal ->
              	    {a,b,c};
              	unused_list_literal ->
              	    [1,2,3,4];
              	unused_integer ->
              	    42;
              	unused_arith ->
              	    X*X;
              	nested ->
              	    [{ok,node(),?MODULE:foo(),self(),[time(),date()],time()},
              	     is_integer(X)];
              	unused_bit_syntax ->
              	    <<X:8>>;
              	unused_fun ->
              	    fun() -> {ok,X} end;
              	unused_atom ->
              	    ignore;				%no warning
              	unused_nil ->
              	    [];					%no warning
                comp_op ->
                    X =:= 2;
                cookie ->
                    erlang:get_cookie();
		result_ignore ->
                    _ = list_to_integer(X);
                warn_lc_4 ->
                    %% No warning because of assignment to _.
                    [_ = abs(Z) || Z <- [1,2,3]]
               end,
               ok.

             %% No warnings should be generated in the following functions.
             m1(X, Sz) ->
                if
             	  Sz =:= 0 -> X = 0;
             	  true -> ok
                end,
                ok.

             m2(X, Sz) ->
                if
             	  Sz =:= 0 -> X = {a,Sz};
             	  true -> ok
                end,
                ok.

             m3(X, Sz) ->
                if
             	  Sz =:= 0 -> X = [a,Sz];
             	  true -> ok
                end,
                ok.

             m4(X, Sz, Var) ->
                if
             	  Sz =:= 0 -> X = Var;
             	  true -> ok
                end,
                ok.

             m5(X, Sz) ->
                if
             	   Sz =:= 0 -> X = {a,b,c};
             	   true -> ok
                end,
                ok.

             m6(X, Sz) ->
                if
             	  Sz =:= 0 -> X = {a,Sz,[1,2,3]};
             	  true -> ok
                end,
                ok.

             m7(X, Sz) ->
                if
             	  Sz =:= 0 -> X = {a,Sz,[1,2,3],abs(Sz)};
             	  true -> ok
                end,
                ok.
             ">>,
	   [],
	   {warnings,[{5,sys_core_fold,{no_effect,{erlang,is_integer,1}}},
		      {7,sys_core_fold,useless_building},
		      {9,sys_core_fold,result_ignored},
		      {9,sys_core_fold,useless_building},
		      {13,sys_core_fold,useless_building},
		      {15,sys_core_fold,useless_building},
		      {17,sys_core_fold,useless_building},
		      {19,sys_core_fold,result_ignored},
		      {21,sys_core_fold,useless_building},
		      {21,sys_core_fold,{no_effect,{erlang,date,0}}},
		      {21,sys_core_fold,{no_effect,{erlang,node,0}}},
		      {21,sys_core_fold,{no_effect,{erlang,self,0}}},
		      {21,sys_core_fold,{no_effect,{erlang,time,0}}},
		      {22,sys_core_fold,useless_building},
		      {22,sys_core_fold,{no_effect,{erlang,is_integer,1}}},
		      {24,sys_core_fold,useless_building},
		      {26,sys_core_fold,useless_building},
		      {32,sys_core_fold,{no_effect,{erlang,'=:=',2}}},
		      {34,sys_core_fold,{no_effect,{erlang,get_cookie,0}}}]}}],
    ?line [] = run(Config, Ts),
    ok.

bin_opt_info(Config) when is_list(Config) ->
    Code = <<"
             t1(Bin) ->
               case Bin of
	         _ when byte_size(Bin) > 20 -> erlang:error(too_long);
                 <<_,T/binary>> -> t1(T);
	         <<>> -> ok
             end.

             t2(<<_,T/bytes>>) ->
               split_binary(T, 4).
           ">>,
    Ts1 = [{bsm1,
	    Code,
	    [bin_opt_info],
	    {warnings,
	     [{4,sys_core_fold,orig_bin_var_used_in_guard},
	      {5,beam_bsm,{no_bin_opt,{{t1,1},no_suitable_bs_start_match}}},
	      {9,beam_bsm,{no_bin_opt,
			   {binary_used_in,{extfunc,erlang,split_binary,2}}}} ]}}],
    ?line [] = run(Config, Ts1),

    %% For coverage: don't give the bin_opt_info option.
    Ts2 = [{bsm2,
	    Code,
	    [],
	    []}],
    ?line [] = run(Config, Ts2),
    ok.

bin_construction(Config) when is_list(Config) ->
    Ts = [{bin_construction,
	   <<"
             t() ->
                 Bin = <<1,2,3>>,
                 <<Bin:4/binary>>.

             x() ->
                 Bin = <<1,2,3,7:4>>,
                 <<Bin/binary>>.
           ">>,
	   [],
	   {warnings,[{4,sys_core_fold,embedded_binary_size},
		      {8,sys_core_fold,{embedded_unit,8,28}}]}}],
    ?line [] = run(Config, Ts),
    
    ok.

%%%
%%% End of test cases.
%%%

run(Config, Tests) ->
    F = fun({N,P,Ws,E}, BadL) ->
                case catch run_test(Config, P, Ws) of
                    E -> 
                        BadL;
                    Bad -> 
                        ?t:format("~nTest ~p failed. Expected~n  ~p~n"
                                  "but got~n  ~p~n", [N, E, Bad]),
			fail()
                end
        end,
    lists:foldl(F, [], Tests).


%% Compiles a test module and returns the list of errors and warnings.

run_test(Conf, Test0, Warnings) ->
    Filename = 'warnings_test.erl',
    ?line DataDir = ?privdir,
    ?line Test = ["-module(warnings_test). ", Test0],
    ?line File = filename:join(DataDir, Filename),
    ?line Opts = [binary,export_all,return|Warnings],
    ?line ok = file:write_file(File, Test),

    %% Compile once just to print all warnings.
    ?line compile:file(File, [binary,export_all,report|Warnings]),

    %% Test result of compilation.
    ?line Res = case compile:file(File, Opts) of
		    {ok, _M, Bin, []} when is_binary(Bin) ->
			[];
		    {ok, _M, Bin, Ws0} when is_binary(Bin) ->
			%% We are not interested in warnings from
			%% erl_lint here.
			WsL = [{F,[W || {_,Mod,_}=W <- Ws, 
					Mod =/= erl_lint]} ||
				  {F,Ws} <- Ws0],
                        case WsL of 
                            [{_File,Ws}] -> {warnings, Ws};
                            _ -> list_to_tuple([warnings, WsL])
                        end
		end,
    file:delete(File),
    Res.

fail() ->
    io:format("failed~n"),
    ?t:fail().
