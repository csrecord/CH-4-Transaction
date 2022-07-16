export const idlFactory = ({ IDL }) => {
  const Company = IDL.Record({
    'principal' : IDL.Principal,
    'desc' : IDL.Text,
    'name' : IDL.Text,
    'webLink' : IDL.Text,
  });
  const DealOrder = IDL.Record({
    'sum' : IDL.Nat,
    'seller' : IDL.Principal,
    'buyOrderIndex' : IDL.Nat,
    'buyer' : IDL.Principal,
    'price' : IDL.Nat,
    'amount' : IDL.Nat,
    'dealTime' : IDL.Int,
    'sellOrderIndex' : IDL.Nat,
  });
  const CancelArgs = IDL.Record({ 'index' : IDL.Nat });
  const Error = IDL.Variant({
    'Insufficient_CH4' : IDL.Null,
    'Insufficient_cny' : IDL.Null,
    'Invaild_index' : IDL.Null,
    'InsufficientAllowance' : IDL.Null,
    'Order_Not_Open' : IDL.Null,
    'InsufficientBalance' : IDL.Null,
    'Transfer_ToUser_Error' : IDL.Null,
    'ErrorOperationStyle' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'LedgerTrap' : IDL.Null,
    'Change_Old_listSellMap_Error' : IDL.Null,
    'TransferFrom_CH4_Error' : IDL.Null,
    'TransferFrom_cny_Error' : IDL.Null,
    'ErrorTo' : IDL.Null,
    'Other' : IDL.Null,
    'BlockUsed' : IDL.Null,
    'Equal_No_Need_Update' : IDL.Null,
    'AmountTooSmall' : IDL.Null,
  });
  const Result_1 = IDL.Variant({ 'ok' : IDL.Nat, 'err' : Error });
  const OrderStatus = IDL.Variant({
    'done' : IDL.Nat,
    'open' : IDL.Nat,
    'cancel' : IDL.Nat,
  });
  const OrderExt = IDL.Record({
    'status' : OrderStatus,
    'createAt' : IDL.Int,
    'owner' : IDL.Principal,
    'index' : IDL.Nat,
    'price' : IDL.Nat,
    'amount' : IDL.Nat,
    'delta' : IDL.Nat,
  });
  const ListArgs = IDL.Record({
    'price' : IDL.Nat,
    'amount' : IDL.Nat,
    'delta' : IDL.Nat,
  });
  const UpdateArgs = IDL.Record({
    'newAmount' : IDL.Nat,
    'index' : IDL.Nat,
    'newPrice' : IDL.Nat,
    'newDelta' : IDL.Nat,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Bool, 'err' : Error });
  const Sell = IDL.Service({
    'addCompany' : IDL.Func([Company], [IDL.Bool], []),
    'addDeals' : IDL.Func([DealOrder], [IDL.Bool], []),
    'cancelBuy' : IDL.Func([CancelArgs], [Result_1], []),
    'cancelSell' : IDL.Func([CancelArgs], [Result_1], []),
    'deal' : IDL.Func([], [], []),
    'getBuyList' : IDL.Func([], [IDL.Vec(OrderExt)], ['query']),
    'getDeals' : IDL.Func([], [IDL.Vec(DealOrder)], ['query']),
    'getRecentMonthDeals' : IDL.Func([], [IDL.Vec(DealOrder)], ['query']),
    'getSellList' : IDL.Func([], [IDL.Vec(OrderExt)], ['query']),
    'getSomebodyBuyList' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(OrderExt)],
        ['query'],
      ),
    'getSomebodySellList' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(OrderExt)],
        ['query'],
      ),
    'getTImeNow' : IDL.Func([], [IDL.Int], ['query']),
    'listBuy' : IDL.Func([ListArgs], [Result_1], []),
    'listSell' : IDL.Func([ListArgs], [Result_1], []),
    'updateBuy' : IDL.Func([UpdateArgs], [Result], []),
    'updateSell' : IDL.Func([UpdateArgs], [Result], []),
    'warning' : IDL.Func([], [IDL.Text], []),
  });
  return Sell;
};
export const init = ({ IDL }) => {
  return [IDL.Principal, IDL.Principal, IDL.Principal, IDL.Principal];
};
