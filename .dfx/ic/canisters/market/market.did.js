export const idlFactory = ({ IDL }) => {
  const Company = IDL.Record({
    'principal' : IDL.Principal,
    'desc' : IDL.Text,
    'name' : IDL.Text,
    'webLink' : IDL.Text,
  });
  const Error = IDL.Variant({
    'Insufficient_CH4' : IDL.Null,
    'Insufficient_cny' : IDL.Null,
    'Invaild_index' : IDL.Null,
    'Order_Not_Open' : IDL.Null,
    'Transfer_ToUser_Error' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'Change_Old_listSellMap_Error' : IDL.Null,
    'TransferFrom_CH4_Error' : IDL.Null,
    'TransferFrom_cny_Error' : IDL.Null,
    'Equal_No_Need_Update' : IDL.Null,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Bool, 'err' : Error });
  const CancelArgs = IDL.Record({ 'index' : IDL.Nat });
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
  const Sell = IDL.Service({
    'addCompany' : IDL.Func([Company], [IDL.Bool], []),
    'burnCh4' : IDL.Func([IDL.Principal, IDL.Nat], [Result], []),
    'cancelBuy' : IDL.Func([CancelArgs], [Result_1], []),
    'cancelSell' : IDL.Func([CancelArgs], [Result_1], []),
    'ch4BalanceOf' : IDL.Func([IDL.Principal], [IDL.Nat], []),
    'cnyBalanceOf' : IDL.Func([IDL.Principal], [IDL.Nat], []),
    'deal' : IDL.Func([], [], []),
    'getBuyList' : IDL.Func([], [IDL.Vec(OrderExt)], ['query']),
    'getPrincipal' : IDL.Func([], [IDL.Principal], ['query']),
    'getSellList' : IDL.Func([], [IDL.Vec(OrderExt)], ['query']),
    'listBuy' : IDL.Func([ListArgs], [Result_1], []),
    'listSell' : IDL.Func([ListArgs], [Result_1], []),
    'mintCh4' : IDL.Func([IDL.Principal, IDL.Nat], [IDL.Bool], []),
    'mintcny' : IDL.Func([IDL.Principal, IDL.Nat], [IDL.Bool], []),
    'updateBuy' : IDL.Func([UpdateArgs], [Result], []),
    'updateSell' : IDL.Func([UpdateArgs], [Result], []),
  });
  return Sell;
};
export const init = ({ IDL }) => {
  return [IDL.Principal, IDL.Principal, IDL.Principal, IDL.Principal];
};
