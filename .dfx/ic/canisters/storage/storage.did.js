export const idlFactory = ({ IDL }) => {
  const OrderStatus = IDL.Variant({
    'done' : IDL.Nat,
    'open' : IDL.Nat,
    'cancel' : IDL.Nat,
  });
  const OrderExt = IDL.Record({
    'status' : OrderStatus,
    'token' : IDL.Principal,
    'createAt' : IDL.Int,
    'tokenIndex' : IDL.Nat,
    'owner' : IDL.Principal,
    'index' : IDL.Nat,
    'price' : IDL.Nat,
  });
  const Direction = IDL.Variant({ 'Buy' : IDL.Null, 'Sell' : IDL.Null });
  const Operation__1 = IDL.Variant({
    'withdraw' : IDL.Record({
      'to' : IDL.Principal,
      'from' : IDL.Principal,
      'amount' : IDL.Nat,
    }),
    'deal' : IDL.Record({
      'seller' : IDL.Principal,
      'orderId' : IDL.Nat,
      'buyer' : IDL.Principal,
      'price' : IDL.Nat,
      'amount' : IDL.Nat,
    }),
    'list' : IDL.Record({
      'direction' : Direction,
      'user' : IDL.Principal,
      'orderId' : IDL.Nat,
      'price' : IDL.Nat,
      'amount' : IDL.Nat,
    }),
    'deposit' : IDL.Record({
      'to' : IDL.Principal,
      'from' : IDL.Principal,
      'amount' : IDL.Nat,
    }),
    'cancel' : IDL.Record({
      'direction' : Direction,
      'user' : IDL.Principal,
      'orderId' : IDL.Nat,
    }),
  });
  const Time = IDL.Int;
  const Operation = IDL.Variant({
    'withdraw' : IDL.Record({
      'to' : IDL.Principal,
      'from' : IDL.Principal,
      'amount' : IDL.Nat,
    }),
    'deal' : IDL.Record({
      'seller' : IDL.Principal,
      'orderId' : IDL.Nat,
      'buyer' : IDL.Principal,
      'price' : IDL.Nat,
      'amount' : IDL.Nat,
    }),
    'list' : IDL.Record({
      'direction' : Direction,
      'user' : IDL.Principal,
      'orderId' : IDL.Nat,
      'price' : IDL.Nat,
      'amount' : IDL.Nat,
    }),
    'deposit' : IDL.Record({
      'to' : IDL.Principal,
      'from' : IDL.Principal,
      'amount' : IDL.Nat,
    }),
    'cancel' : IDL.Record({
      'direction' : Direction,
      'user' : IDL.Principal,
      'orderId' : IDL.Nat,
    }),
  });
  const OpRecord = IDL.Record({
    'op' : Operation,
    'timestamp' : IDL.Int,
    'index' : IDL.Nat,
  });
  const ItemInfo = IDL.Record({
    'id' : IDL.Nat,
    'to' : IDL.Principal,
    'from' : IDL.Principal,
    'time' : IDL.Int,
    'price' : IDL.Nat,
  });
  const PriceInfo = IDL.Record({
    'avg' : IDL.Nat,
    'max' : IDL.Nat,
    'min' : IDL.Nat,
    'num' : IDL.Nat,
    'date' : IDL.Int,
    'volume' : IDL.Nat,
  });
  const Storage = IDL.Service({
    'addOrder' : IDL.Func([OrderExt], [IDL.Nat], []),
    'addRecord' : IDL.Func([IDL.Principal, Operation__1, Time], [IDL.Nat], []),
    'allHistory' : IDL.Func([], [IDL.Vec(OpRecord)], ['query']),
    'clearData' : IDL.Func([], [IDL.Bool], []),
    'getCollectionHistoryOrders' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(OrderExt)],
        ['query'],
      ),
    'getCycles' : IDL.Func([], [IDL.Nat], ['query']),
    'getItemHistory' : IDL.Func(
        [IDL.Principal, IDL.Int, IDL.Int],
        [IDL.Vec(ItemInfo)],
        ['query'],
      ),
    'getPriceHistory' : IDL.Func(
        [IDL.Principal, IDL.Int, IDL.Int],
        [IDL.Vec(PriceInfo)],
        ['query'],
      ),
    'getTokenHistoryOrders' : IDL.Func(
        [IDL.Principal, IDL.Nat],
        [IDL.Vec(OrderExt)],
        ['query'],
      ),
    'getTransaction' : IDL.Func([IDL.Nat], [OpRecord], ['query']),
    'getTransactions' : IDL.Func(
        [IDL.Nat, IDL.Nat],
        [IDL.Vec(OpRecord)],
        ['query'],
      ),
    'getUserOrderAmount' : IDL.Func([IDL.Principal], [IDL.Nat], ['query']),
    'getUserOrders' : IDL.Func(
        [IDL.Principal, IDL.Nat, IDL.Nat],
        [IDL.Vec(OrderExt)],
        ['query'],
      ),
    'getUserTransactionAmount' : IDL.Func(
        [IDL.Principal],
        [IDL.Nat],
        ['query'],
      ),
    'getUserTransactions' : IDL.Func(
        [IDL.Principal, IDL.Nat, IDL.Nat],
        [IDL.Vec(OpRecord)],
        ['query'],
      ),
    'marketCanisterId' : IDL.Func([], [IDL.Principal], ['query']),
    'opAmount' : IDL.Func([], [IDL.Nat], ['query']),
    'owner' : IDL.Func([], [IDL.Principal], ['query']),
    'setMarketCanisterId' : IDL.Func([IDL.Principal], [IDL.Bool], []),
  });
  return Storage;
};
export const init = ({ IDL }) => { return [IDL.Principal, IDL.Principal]; };
