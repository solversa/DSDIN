
-module(dsdc_accounts).

%% API
-export([new/2,
         pubkey/1,
         balance/1,
         nonce/1,
         earn/2,
         spend/3,
         spend_without_nonce_bump/2,
         set_nonce/2,
         serialize/1,
         deserialize/1]).


-define(ACCOUNT_VSN, 1).
-define(ACCOUNT_TYPE, account).

-record(account, {
          pubkey = <<>>  :: <<>> | dsdc_keys:pubkey(),
          balance = 0    :: non_neg_integer(),
          nonce = 0      :: non_neg_integer()}).

-opaque account() :: #account{}.
-export_type([account/0, deterministic_account_binary_with_pubkey/0]).

-type deterministic_account_binary_with_pubkey() :: binary().

-spec new(dsdc_keys:pubkey(), non_neg_integer()) -> account().
new(Pubkey, Balance) ->
    #account{pubkey = Pubkey, balance = Balance}.

-spec pubkey(account()) -> dsdc_keys:pubkey().
pubkey(#account{pubkey = Pubkey}) ->
    Pubkey.

-spec balance(account()) -> non_neg_integer().
balance(#account{balance = Balance}) ->
    Balance.

-spec nonce(account()) -> non_neg_integer().
nonce(#account{nonce = Nonce}) ->
    Nonce.

%% Only used for tests
-spec set_nonce(account(), non_neg_integer()) -> account().
set_nonce(Account, NewNonce) ->
    Account#account{nonce = NewNonce}.

-spec earn(account(), non_neg_integer()) -> {ok, account()}.
earn(#account{balance = Balance0} = Account0, Amount) ->
    {ok, Account0#account{balance = Balance0 + Amount}}.

-spec spend(account(), non_neg_integer(), non_neg_integer()) -> {ok, account()}.
spend(#account{balance = Balance0} = Account0, Amount, Nonce) ->
    {ok, Account0#account{balance = Balance0 - Amount,
                          nonce = Nonce}}.

-spec spend_without_nonce_bump(account(), non_neg_integer()) -> {ok, account()}.
%%% NOTE: Only use this if you actually don't want to update the nonce
%%% of the account (e.g., when opening a state channel).
spend_without_nonce_bump(#account{balance = Balance0} = Account0, Amount) ->
    {ok, Account0#account{balance = Balance0 - Amount}}.

-spec serialize(account()) -> deterministic_account_binary_with_pubkey().
serialize(Account) ->
    dsdc_object_serialization:serialize(
      ?ACCOUNT_TYPE, ?ACCOUNT_VSN,
      serialization_template(?ACCOUNT_VSN),
      [ {pubkey, pubkey(Account)}
      , {nonce, nonce(Account)}
      , {balance, balance(Account)}
      ]).

-spec deserialize(binary()) -> account().
deserialize(SerializedAccount) ->
    [ {pubkey, Pubkey}
    , {nonce, Nonce}
    , {balance, Balance}
    ] = dsdc_object_serialization:deserialize(
          ?ACCOUNT_TYPE,
          ?ACCOUNT_VSN,
          serialization_template(?ACCOUNT_VSN),
          SerializedAccount),
    #account{ pubkey = Pubkey
            , balance = Balance
            , nonce = Nonce
            }.

serialization_template(?ACCOUNT_VSN) ->
    [ {pubkey, binary}
    , {nonce, int}
    , {balance, int}
    ].
