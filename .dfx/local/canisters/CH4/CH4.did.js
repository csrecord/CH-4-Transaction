export const idlFactory = ({ IDL }) => {
  const Company = IDL.Record({
    'principal' : IDL.Principal,
    'desc' : IDL.Text,
    'name' : IDL.Text,
    'webLink' : IDL.Text,
  });
  const CancelArgs = IDL.Record({ 'index' : IDL.Nat });
  const Error = IDL.Variant({
    'Insufficient_CH4' : IDL.Null,
    'Invaild_index' : IDL.Null,
    'Order_Not_Open' : IDL.Null,
    'Delete_Old_listSellMap_Error' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'Change_Old_listSellMap_Error' : IDL.Null,
    'TransferFrom_CH4_Error' : IDL.Null,
    'Insufficient_money' : IDL.Null,
    'TransferFrom_ToUser_Error' : IDL.Null,
  });
  const Result_1 = IDL.Variant({ 'ok' : IDL.Null, 'err' : Error });
  const Result_2 = IDL.Variant({ 'ok' : IDL.Nat, 'err' : Error });
  const ListArgs = IDL.Record({ 'price' : IDL.Nat, 'amount' : IDL.Nat });
  const UpdateArgs = IDL.Record({ 'index' : IDL.Nat, 'newPrice' : IDL.Nat });
  const Result = IDL.Variant({ 'ok' : IDL.Bool, 'err' : Error });
  const Sell = IDL.Service({
    'addCompany' : IDL.Func([Company], [IDL.Bool], []),
    'cancelBuy' : IDL.Func([CancelArgs], [Result_1], []),
    'cancelSell' : IDL.Func([CancelArgs], [Result_2], []),
    'deal' : IDL.Func([], [], []),
    'getBuyList' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Nat, IDL.Nat))],
        ['query'],
      ),
    'getSellList' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Nat, IDL.Nat))],
        ['query'],
      ),
    'listBuy' : IDL.Func([ListArgs], [Result_1], []),
    'listSell' : IDL.Func([ListArgs], [Result_2], []),
    'updateBuyPrice' : IDL.Func([UpdateArgs], [Result_1], []),
    'updateSellPrice' : IDL.Func([UpdateArgs], [Result], []),
  });
  return Sell;
};
export const init = ({ IDL }) => {
  return [IDL.Principal, IDL.Principal, IDL.Principal, IDL.Principal];
};
