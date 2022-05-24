import type { Principal } from '@dfinity/principal';
export interface CancelArgs { 'index' : bigint }
export interface Company {
  'principal' : Principal,
  'desc' : string,
  'name' : string,
  'webLink' : string,
}
export type Error = { 'Insufficient_CH4' : null } |
  { 'Invaild_index' : null } |
  { 'Order_Not_Open' : null } |
  { 'Delete_Old_listSellMap_Error' : null } |
  { 'Insufficient_wicp' : null } |
  { 'NewPrice_Equal_OldPrice' : null } |
  { 'Unauthorized' : null } |
  { 'Change_Old_listSellMap_Error' : null } |
  { 'TransferFrom_CH4_Error' : null } |
  { 'TransferFrom_ToUser_Error' : null } |
  { 'TransferFrom_wicp_Error' : null };
export interface ListArgs { 'price' : bigint, 'amount' : bigint }
export type Result = { 'ok' : boolean } |
  { 'err' : Error };
export type Result_1 = { 'ok' : bigint } |
  { 'err' : Error };
export interface Sell {
  'addCompany' : (arg_0: Company) => Promise<boolean>,
  'cancelBuy' : (arg_0: CancelArgs) => Promise<Result_1>,
  'cancelSell' : (arg_0: CancelArgs) => Promise<Result_1>,
  'deal' : () => Promise<undefined>,
  'getBuyList' : () => Promise<Array<[bigint, bigint]>>,
  'getSellList' : () => Promise<Array<[bigint, bigint]>>,
  'listBuy' : (arg_0: ListArgs) => Promise<Result_1>,
  'listSell' : (arg_0: ListArgs) => Promise<Result_1>,
  'updateBuyPrice' : (arg_0: UpdateArgs) => Promise<Result>,
  'updateSellPrice' : (arg_0: UpdateArgs) => Promise<Result>,
}
export interface UpdateArgs { 'index' : bigint, 'newPrice' : bigint }
export interface _SERVICE extends Sell {}
