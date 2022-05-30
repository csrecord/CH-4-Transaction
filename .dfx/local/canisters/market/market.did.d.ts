import type { Principal } from '@dfinity/principal';
export interface CancelArgs { 'index' : bigint }
export interface Company {
  'principal' : Principal,
  'desc' : string,
  'name' : string,
  'webLink' : string,
}
export type Error = { 'Insufficient_CH4' : null } |
  { 'Insufficient_cny' : null } |
  { 'Invaild_index' : null } |
  { 'Order_Not_Open' : null } |
  { 'Transfer_ToUser_Error' : null } |
  { 'Unauthorized' : null } |
  { 'Change_Old_listSellMap_Error' : null } |
  { 'TransferFrom_CH4_Error' : null } |
  { 'TransferFrom_cny_Error' : null } |
  { 'Equal_No_Need_Update' : null };
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
export interface Sell {
  'addCompany' : (arg_0: Company) => Promise<boolean>,
  'cancelBuy' : (arg_0: CancelArgs) => Promise<Result_1>,
  'cancelSell' : (arg_0: CancelArgs) => Promise<Result_1>,
  'deal' : () => Promise<undefined>,
  'getBuyList' : () => Promise<Array<OrderExt>>,
  'getSellList' : () => Promise<Array<OrderExt>>,
  'listBuy' : (arg_0: ListArgs) => Promise<Result_1>,
  'listSell' : (arg_0: ListArgs) => Promise<Result_1>,
  'updateBuy' : (arg_0: UpdateArgs) => Promise<Result>,
  'updateSell' : (arg_0: UpdateArgs) => Promise<Result>,
}
export interface UpdateArgs {
  'newAmount' : bigint,
  'index' : bigint,
  'newPrice' : bigint,
  'newDelta' : bigint,
}
export interface _SERVICE extends Sell {}