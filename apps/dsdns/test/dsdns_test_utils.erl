
-module(dsdns_test_utils).

%% API
-export([new_state/0,
         trees/1,
         set_trees/2,
         priv_key/2,
         setup_new_account/1,
         set_account_balance/3,
         revoke_name/2,
         preclaim_tx_spec/3,
         preclaim_tx_spec/4,
         claim_tx_spec/4,
         claim_tx_spec/5,
         update_tx_spec/3,
         update_tx_spec/4,
         transfer_tx_spec/4,
         transfer_tx_spec/5,
         revoke_tx_spec/3,
         revoke_tx_spec/4]).

-include_lib("apps/dsdns/include/ns_txs.hrl").

%%%===================================================================
%%% Test state
%%%===================================================================

%% TODO: Move test state to a place so that it can be shared between apps,
%% e.g. dsdoracle_SUITE uses similar code

new_state() ->
    #{}.

trees(#{} = S) ->
    maps:get(trees, S, dsdc_trees:new()).

set_trees(Trees, S) ->
    S#{trees => Trees}.

priv_key(PubKey, State) ->
    maps:get(PubKey, key_pairs(State)).

key_pairs(S) ->
    maps:get(key_pairs, S, #{}).

next_nonce(PubKey, S) ->
    Account = dsdc_accounts_trees:get(PubKey, dsdc_trees:accounts(trees(S))),
    dsdc_accounts:nonce(Account) + 1.

insert_key_pair(Pub, Priv, S) ->
    Old = key_pairs(S),
    S#{key_pairs => Old#{Pub => Priv}}.

%%%===================================================================
%%% Accounts utils
%%%===================================================================

%% TODO: Move all account utils to a place so that it can be shared between apps,
%% e.g. dsdoracle_SUITE uses similar code

-define(PRIV_SIZE, 32).

setup_new_account(State) ->
    setup_new_account(1000, State).

set_account_balance(PubKey, NewBalance, State) ->
    A        = get_account(PubKey, State),
    Balance  = dsdc_accounts:balance(A),
    Nonce    = dsdc_accounts:nonce(A),
    {ok, A1} = dsdc_accounts:spend(A, Balance, Nonce),
    {ok, A2} = dsdc_accounts:earn(A1, NewBalance),
    set_account(A2, State).

get_account(PubKey, State) ->
    dsdc_accounts_trees:get(PubKey, dsdc_trees:accounts(trees(State))).

setup_new_account(Balance, State) ->
    {PubKey, PrivKey} = new_key_pair(),
    State1 = insert_key_pair(PubKey, PrivKey, State),
    State2 = set_account(dsdc_accounts:new(PubKey, Balance), State1),
    {PubKey, State2}.

new_key_pair() ->
    #{ public := PubKey, secret := PrivKey } = enacl:sign_keypair(),
    {PubKey, PrivKey}.

set_account(Account, State) ->
    Trees   = trees(State),
    AccTree = dsdc_accounts_trees:enter(Account, dsdc_trees:accounts(Trees)),
    set_trees(dsdc_trees:set_accounts(Trees, AccTree), State).

%%%===================================================================
%%% Names utils
%%%===================================================================

revoke_name(N, State) ->
    Trees = trees(State),
    N1 = dsdns_names:revoke(N, 5, 10),
    NSTree = dsdns_state_tree:enter_name(N1, dsdc_trees:ns(Trees)),
    set_trees(dsdc_trees:set_ns(Trees, NSTree), State).

%%%===================================================================
%%% Preclaim tx
%%%===================================================================

preclaim_tx_spec(PubKey, Commitment, State) ->
    preclaim_tx_spec(PubKey, Commitment, #{}, State).

preclaim_tx_spec(PubKey, Commitment, Spec0, State) ->
    Spec = maps:merge(preclaim_tx_default_spec(PubKey, State), Spec0),
    #{account    => PubKey,
      nonce      => maps:get(nonce, Spec),
      commitment => Commitment,
      fee        => maps:get(fee, Spec),
      ttl        => maps:get(ttl, Spec)}.

preclaim_tx_default_spec(PubKey, State) ->
    #{nonce => try next_nonce(PubKey, State) catch _:_ -> 0 end,
      fee   => 3,
      ttl   => 100}.

%%%===================================================================
%%% Claim tx
%%%===================================================================

claim_tx_spec(PubKey, Name, NameSalt, State) ->
    claim_tx_spec(PubKey, Name, NameSalt, #{}, State).

claim_tx_spec(PubKey, Name, NameSalt, Spec0, State) ->
    Spec = maps:merge(claim_tx_default_spec(PubKey, State), Spec0),
    #{account   => PubKey,
      nonce     => maps:get(nonce, Spec),
      name      => Name,
      name_salt => NameSalt,
      fee       => maps:get(fee, Spec),
      ttl       => maps:get(ttl, Spec)}.

claim_tx_default_spec(PubKey, State) ->
    #{nonce => try next_nonce(PubKey, State) catch _:_ -> 0 end,
      fee   => 3,
      ttl   => 100}.

%%%===================================================================
%%% Update tx
%%%===================================================================

update_tx_spec(PubKey, NameHash, State) ->
    update_tx_spec(PubKey, NameHash, #{}, State).

update_tx_spec(PubKey, NameHash, Spec0, State) ->
    Spec = maps:merge(update_tx_default_spec(PubKey, State), Spec0),
    #{account    => PubKey,
      nonce      => maps:get(nonce, Spec),
      name_hash  => NameHash,
      name_ttl   => maps:get(name_ttl, Spec),
      pointers   => maps:get(pointers, Spec),
      client_ttl => maps:get(client_ttl, Spec),
      fee        => maps:get(fee, Spec),
      ttl        => maps:get(ttl, Spec)}.

update_tx_default_spec(PubKey, State) ->
    #{nonce      => try next_nonce(PubKey, State) catch _:_ -> 0 end,
      name_ttl   => 20000,
      pointers   => [{<<"key">>, <<"val">>}],
      client_ttl => 60000,
      fee        => 3,
      ttl        => 100}.

%%%===================================================================
%%% Transfer tx
%%%===================================================================

transfer_tx_spec(PubKey, NameHash, RecipientAccount, State) ->
    transfer_tx_spec(PubKey, NameHash, RecipientAccount, #{}, State).

transfer_tx_spec(PubKey, NameHash, RecipientAccount, Spec0, State) ->
    Spec = maps:merge(transfer_tx_default_spec(PubKey, State), Spec0),
    #{account           => PubKey,
      nonce             => maps:get(nonce, Spec),
      name_hash         => NameHash,
      recipient_account => RecipientAccount,
      fee               => maps:get(fee, Spec),
      ttl               => maps:get(ttl, Spec)}.

transfer_tx_default_spec(PubKey, State) ->
    #{nonce => try next_nonce(PubKey, State) catch _:_ -> 0 end,
      fee   => 3,
      ttl   => 100}.

%%%===================================================================
%%% Revoke tx
%%%===================================================================

revoke_tx_spec(PubKey, NameHash, State) ->
    revoke_tx_spec(PubKey, NameHash, #{}, State).

revoke_tx_spec(PubKey, NameHash, Spec0, State) ->
    Spec = maps:merge(revoke_tx_default_spec(PubKey, State), Spec0),
    #{account   => PubKey,
      nonce     => maps:get(nonce, Spec),
      name_hash => NameHash,
      fee       => maps:get(fee, Spec),
      ttl       => maps:get(ttl, Spec)}.

revoke_tx_default_spec(PubKey, State) ->
    #{nonce => try next_nonce(PubKey, State) catch _:_ -> 0 end,
      fee   => 3,
      ttl   => 100}.