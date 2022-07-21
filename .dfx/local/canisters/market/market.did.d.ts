import type { Principal } from '@dfinity/principal';
export interface CancelArgs { 'index' : bigint }
export interface Company {
  'principal' : Principal,
  'desc' : string,
  'name' : string,
  'webLink' : string,
}
export interface DealOrder {
  'sum' : bigint,
  'seller' : Principal,
  'buyOrderIndex' : bigint,
  'buyer' : Principal,
  'price' : bigint,
  'amount' : bigint,
  'dealTime' : bigint,
  'sellOrderIndex' : bigint,
}
export type Error = { 'Insufficient_CH4' : null } |
  { 'Insufficient_cny' : null } |
  { 'Invaild_index' : null } |
  { 'InsufficientAllowance' : null } |
  { 'Order_Not_Open' : null } |
  { 'InsufficientBalance' : null } |
  { 'Transfer_ToUser_Error' : null } |
  { 'ErrorOperationStyle' : null } |
  { 'Unauthorized' : null } |
  { 'LedgerTrap' : null } |
  { 'Change_Old_listSellMap_Error' : null } |
  { 'TransferFrom_CH4_Error' : null } |
  { 'TransferFrom_cny_Error' : null } |
  { 'ErrorTo' : null } |
  { 'Other' : null } |
  { 'BlockUsed' : null } |
  { 'Equal_No_Need_Update' : null } |
  { 'AmountTooSmall' : null };
export interface ListArgs {
  'price' : bigint,
  'amount' : bigint,
  'delta' : bigint,
}
export interface OrderExt {
  'status' : OrderStatus,
  'createAt' : bigint,
  'owner' : Principal,
  'index' : bigint,
  'price' : bigint,
  'amount' : bigint,
  'delta' : bigint,
}
export type OrderStatus = { 'done' : bigint } |
  { 'open' : bigint } |
  { 'cancel' : bigint };
export type Result = { 'ok' : boolean } |
  { 'err' : Error };
export type Result_1 = { 'ok' : bigint } |
  { 'err' : Error };
export type Result_2 = { 'ok' : Company } |
  { 'err' : string };
export interface Sell {
  'addCompany' : (arg_0: Company) => Promise<boolean>,
  'addDeals' : (arg_0: DealOrder) => Promise<boolean>,
  'cancelBuy' : (arg_0: CancelArgs) => Promise<Result_1>,
  'cancelSell' : (arg_0: CancelArgs) => Promise<Result_1>,
  'deal' : () => Promise<undefined>,
  'fromBuy_balanceof' : (arg_0: Principal) => Promise<bigint>,
  'getAllCompanyPr' : () => Promise<Array<Principal>>,
  'getBuyList' : () => Promise<Array<OrderExt>>,
  'getCompanyInfo' : (arg_0: Principal) => Promise<Result_2>,
  'getDeals' : () => Promise<Array<DealOrder>>,
  'getRecentMonthDeals' : () => Promise<Array<DealOrder>>,
  'getSellList' : () => Promise<Array<OrderExt>>,
  'getSomebodyBuyList' : (arg_0: Principal) => Promise<Array<OrderExt>>,
  'getSomebodySellList' : (arg_0: Principal) => Promise<Array<OrderExt>>,
  'getTImeNow' : () => Promise<bigint>,
  'listBuy' : (arg_0: ListArgs) => Promise<Result_1>,
  'listSell' : (arg_0: ListArgs) => Promise<Result_1>,
  'toSell_balanceof' : (arg_0: Principal) => Promise<bigint>,
  'updateBuy' : (arg_0: UpdateArgs) => Promise<Result>,
  'updateSell' : (arg_0: UpdateArgs) => Promise<Result>,
  'warning' : () => Promise<string>,
}
export interface UpdateArgs {
  'newAmount' : bigint,
  'index' : bigint,
  'newPrice' : bigint,
  'newDelta' : bigint,
}
export interface _SERVICE extends Sell {}
