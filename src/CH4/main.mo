import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import TrieSet "mo:base/TrieSet";
import Result "mo:base/Result";

import Types "types";

shared(installer) actor class Sell(admin_ : Principal,wicp_: Principal,ch4_: Principal,storage_: Principal) = this {

  public type Error = {
    #Insufficient_wicp;
    #Insufficient_CH4;
    #TransferFrom_CH4_Error;
    #Invaild_index;
    #Unauthorized;
    #Order_Not_Open;
    #Change_Old_listSellMap_Error;
    #Delete_Old_listSellMap_Error;
    #TransferFrom_ToUser_Error;
    #TransferFrom_wicp_Error;
    #NewPrice_Equal_OldPrice;
  };
  
  // DIP20 token actor
  public type TokenError = {
    #InsufficientBalance;
    #InsufficientAllowance;
    #LedgerTrap;
    #AmountTooSmall;
    #BlockUsed;
    #ErrorOperationStyle;
    #ErrorTo;
    #Other;
  };
  
  public type TxReceiptToken = {
    #Ok: Nat;
    #Err: TokenError;
  };
  
  type TokenActor = actor {
      allowance: shared (owner: Principal, spender: Principal) -> async Nat;
      approve: shared (spender: Principal, value: Nat) -> async TxReceiptToken;
      balanceOf: (owner: Principal) -> async Nat;
      decimals: () -> async Nat8;
      name: () -> async Text;
      symbol: () -> async Text;
      totalSupply: () -> async Nat;
      transfer: shared (to: Principal, value: Nat) -> async TxReceiptToken;
      transferFrom: shared (from: Principal, to: Principal, value: Nat) -> async TxReceiptToken;
  };

  type StorageActor = actor {
      addRecord: shared (caller: Principal, op: Operation, timestamp: Time.Time) -> async Nat;
      addOrder:  shared (order: OrderExt) -> async Nat;
  };
  type TxReceipt = Result.Result<Nat, Text>;
  type Operation = Types.Operation;
  type OrderExt = Types.OrderExt;
  type Company = Types.Company;
  type Order = Types.Order;
  type ListArgs = Types.ListArgs;
  type UpdateArgs = Types.UpdateArgs;
  type CancelArgs = Types.CancelArgs;
  private stable var wicp: TokenActor = actor(Principal.toText(wicp_));
  private stable var ch4: TokenActor = actor(Principal.toText(ch4_));
  private stable var storage: StorageActor = actor(Principal.toText(storage_));
  let listSellArray: [var Nat] = Array.init<Nat>(50010,0);
  let listBuyArray:  [var Nat] = Array.init<Nat>(50010,0);
  stable var listSellMap_entries: [(Nat, TrieSet.Set<Order>)] = [];
  stable var listBuyMap_entries: [(Nat, TrieSet.Set<Order>)] = [];
  stable var sells_entries: [(Nat, Order)] = [];
  stable var buys_entries: [(Nat, Order)] = [];
  stable var companys_entries: [(Principal, Company)] = [];
  stable var listSellIndex = 0;
  stable var listBuyIndex = 0;
  stable var listSellMin = 60000;
  stable var listSellMin_Number = 0;
  stable var listBuyMax = 0;
  stable var listBuyMax_Number = 0;
  stable var txcounter = 0;
  var listSellMap: TrieMap.TrieMap<Nat, TrieSet.Set<Order>> = TrieMap.fromEntries<Nat, TrieSet.Set<Order>>(listSellMap_entries.vals(), Nat.equal, Hash.hash);
  var listBuyMap: TrieMap.TrieMap<Nat, TrieSet.Set<Order>> = TrieMap.fromEntries<Nat, TrieSet.Set<Order>>(listBuyMap_entries.vals(), Nat.equal, Hash.hash);
  var sells: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(sells_entries.vals(), Nat.equal, Hash.hash);
  var buys: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(buys_entries.vals(), Nat.equal, Hash.hash);
  var companys: TrieMap.TrieMap<Principal, Company> = TrieMap.fromEntries<Principal, Company>(companys_entries.vals(), Principal.equal, Principal.hash);

  // 限价挂出售单
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将ch4转到平台账户
  // 创建一个Order订单
  // 在listSellArray增加相应的值，并更新最小值
  // listSellMap中记录 k -> 价格 
  // sells 中记录 k -> index
  // Tx记录
  public shared({caller}) func listSell(
      args: ListArgs
  ): async Result.Result<Nat, Error> {
      let balance = await ch4.balanceOf(caller);
      if(balance < args.amount) { return #err(#Insufficient_CH4);};
      switch(await ch4.transferFrom(caller, Principal.fromActor(this), args.amount)) {
          case(#Ok(id)) {};
          case(#Err(e)) { return #err(#TransferFrom_CH4_Error);};
      }; 
      listSellIndex += 1;
      txcounter += 1;
      let order: Order = {
          index = listSellIndex;
          amount = args.amount;
          owner = caller;
          var price = args.price;
          var status = #open(txcounter);
          createAt = Time.now();
      };
      listSellArray[args.price] += args.amount;
      if(args.price < listSellMin) {
          listSellMin := args.price;
          listSellMin_Number := 1;
      } else if(args.price == listSellMin) {
          listSellMin_Number += 1;
      };
      switch(listSellMap.get(args.price)) {
          case(null) {
              let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
              listSellMap.put(args.price, orderSet);
          };
          case(?orderSet) {
              let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listSellMap.put(args.price, newOrderSet);
          };
      };
      sells.put(listSellIndex, order);
      ignore storage.addRecord(caller, #list({orderId = order.index; user = caller; price = args.price; amount = args.amount; direction = #Sell;}), Time.now());
      return #ok(order.index);
  };

  public shared({caller}) func updateSellPrice(
      args: UpdateArgs
  ): async Result.Result<Bool, Error> {
      let order = switch(sells.get(args.index)) {
          case(null) { return #err(#Invaild_index);};
          case(?o) { o }; 
      };
      if(caller != order.owner) return #err(#Unauthorized);
      switch(order.status) {
          case(#open(id)) {};
          case(_) { return #err(#Order_Not_Open);};
      };
      if(order.price == args.newPrice) return #err(#NewPrice_Equal_OldPrice);
      listSellArray[order.price] -= order.amount;
      switch(listSellMap.get(order.price)) {
          case(null) { return #err(#Change_Old_listSellMap_Error);};
          case(?orderSet) {
              let newOrderSet = TrieSet.delete(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listSellMap.put(order.price, newOrderSet);
          };
      };
      if(order.price == listSellMin) {
          if(args.newPrice < listSellMin) {
              listSellMin := args.newPrice;
              listSellMin_Number := 1;
          } else if(args.newPrice > listSellMin) {
              if(listSellMin_Number > 1) {
                  listSellMin_Number -= 1;
              } else {
                  listSellMin := 60000;
                  listSellMin_Number := 1;
              };
          }; 
      };
      order.price := args.newPrice;
      listSellArray[args.newPrice] += order.amount;
      switch(listSellMap.get(args.newPrice)) {
          case(null) {
              let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
              listSellMap.put(args.newPrice, orderSet);
          };
          case(?orderSet) {
              let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listSellMap.put(args.newPrice, newOrderSet);
          };
      };
      sells.put(args.index, order);
      return #ok(true);
  };

  public shared({caller}) func cancelSell(
      args: CancelArgs
  ): async Result.Result<Nat, Error> {
      let order = switch(sells.get(args.index)) {
          case(null) { return #err(#Invaild_index);};
          case(?o) { o };
      };
      switch(order.status) {
          case(#open(id)) {};
          case(_) { return #err(#Order_Not_Open);};
      };
      if(caller != order.owner) return #err(#Unauthorized);
      sells.delete(args.index);
      switch(listSellMap.get(order.price)) {
          case(null) { return #err(#Delete_Old_listSellMap_Error)};
          case(?orderSet) {
              let newOrderSet = TrieSet.delete(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listSellMap.put(order.price, newOrderSet);
          }; 
      };
      listSellArray[order.price] -= order.amount;
      if(order.price == listSellMin) {
          if(listSellMin_Number > 1) {
              listSellMin_Number -= 1;
          } else {
              listSellMin_Number := 0;
              listSellMin := 60000
          };
      };
      switch(await ch4.transferFrom(Principal.fromActor(this), caller, order.amount)) {
          case(#Ok(id)) {
              txcounter += 1;
              order.status := #cancel(txcounter);
              ignore storage.addOrder(_toOrderExt(order));
              ignore storage.addRecord(caller, #cancel({orderId = order.index; user = caller; direction = #Sell}), Time.now());
              return #ok(txcounter);
          };
          case(#Err(e)) {
              sells.put(args.index, order);
              switch(listSellMap.get(order.price)) {
                  case(null) {
                      let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
                      listSellMap.put(order.price, orderSet);
                  };
                  case(?orderSet) {
                      let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
                      listSellMap.put(order.price, newOrderSet);
                  };
              };
              if(order.price == listSellMin) {
                  if(listSellMin_Number > 0) listSellMin_Number += 1;
                  if(listSellMin_Number == 0) {
                      listSellMin_Number := 1;
                      listSellMin := order.price;
                  };
              };
              return #err(#TransferFrom_ToUser_Error);
          };
      };
  };

  private func _toOrderExt(order: Order): OrderExt {
      {
          index = order.index;
          amount = order.amount;
          owner = order.owner;
          price = order.price;
          status = order.status;
          createAt = order.createAt;
      }
  };

  // 限价挂买入单
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将wicp转到平台账户
  // 创建一个Order订单
  // 在listBuyArray增加相应的值，并更新最大值
  // listBuyMap中记录
  // Tx记录
  public shared({caller}) func listBuy(
      args: ListArgs
  ): async Result.Result<Nat, Error> {
      let balance = await wicp.balanceOf(caller);
      if(balance < args.amount) { return #err(#Insufficient_wicp);};
      switch(await wicp.transferFrom(caller, Principal.fromActor(this), args.amount)) {
          case(#Ok(id)) {};
          case(#Err(e)) { return #err(#TransferFrom_wicp_Error);};
      }; 
      listBuyIndex += 1;
      txcounter += 1;
      let order: Order = {
          index = listBuyIndex;
          amount = args.amount;
          owner = caller;
          var price = args.price;
          var status = #open(txcounter);
          createAt = Time.now();
      };
      listBuyArray[args.price] += args.amount;
      if(args.price > listBuyMax) {
          listBuyMax := args.price;
          listBuyMax_Number := 1;
      } else if(args.price == listBuyMax) {
          listBuyMax_Number += 1;
      };
      switch(listBuyMap.get(args.price)) {
          case(null) {
              let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
              listBuyMap.put(args.price, orderSet);
          };
          case(?orderSet) {
              let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listBuyMap.put(args.price, newOrderSet);
          };
      };
      buys.put(listBuyIndex, order);
      ignore storage.addRecord(caller, #list({orderId = order.index; user = caller; price = args.price; amount = args.amount; direction = #Buy;}), Time.now());
      return #ok(order.index);
  };

  public shared({caller}) func updateBuyPrice(
      args: UpdateArgs
  ): async Result.Result<Bool, Error> {
      let order = switch(buys.get(args.index)) {
          case(null) { return #err(#Invaild_index);};
          case(?o) { o }; 
      };
      if(caller != order.owner) return #err(#Unauthorized);
      switch(order.status) {
          case(#open(id)) {};
          case(_) { return #err(#Order_Not_Open);};
      };
      if(order.price == args.newPrice) return #err(#NewPrice_Equal_OldPrice);
      listBuyArray[order.price] -= order.amount;
      switch(listBuyMap.get(order.price)) {
          case(null) { return #err(#Change_Old_listSellMap_Error);};
          case(?orderSet) {
              let newOrderSet = TrieSet.delete(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listBuyMap.put(order.price, newOrderSet);
          };
      };
      if(order.price == listBuyMax) {
          if(args.newPrice > listBuyMax) {
              listBuyMax := args.newPrice;
              listBuyMax_Number := 1;
          } else if(args.newPrice < listBuyMax) {
              if(listBuyMax_Number > 1) {
                  listBuyMax_Number -= 1;
              } else {
                  listBuyMax := 0;
                  listBuyMax_Number := 1;
              };
          }; 
      };
      order.price := args.newPrice;
      listBuyArray[args.newPrice] += order.amount;
      switch(listBuyMap.get(args.newPrice)) {
          case(null) {
              let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
              listBuyMap.put(args.newPrice, orderSet);
          };
          case(?orderSet) {
              let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listBuyMap.put(args.newPrice, newOrderSet);
          };
      };
      buys.put(args.index, order);
      return #ok(true);
  };

  public shared({caller}) func cancelBuy(
      args: CancelArgs
  ): async Result.Result<Nat, Error> {
      let order = switch(buys.get(args.index)) {
          case(null) { return #err(#Invaild_index);};
          case(?o) { o };
      };
      switch(order.status) {
          case(#open(id)) {};
          case(_) { return #err(#Order_Not_Open);};
      };
      if(caller != order.owner) return #err(#Unauthorized);
      buys.delete(args.index);
      switch(listBuyMap.get(order.price)) {
          case(null) { return #err(#Delete_Old_listSellMap_Error)};
          case(?orderSet) {
              let newOrderSet = TrieSet.delete(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
              listBuyMap.put(order.price, newOrderSet);
          }; 
      };
      listBuyArray[order.price] -= order.amount;
      if(order.price == listBuyMax) {
          if(listBuyMax_Number > 1) {
              listBuyMax_Number -= 1;
          } else {
              listBuyMax_Number := 0;
              listBuyMax := 0;
          };
      };
      switch(await wicp.transferFrom(Principal.fromActor(this), caller, order.amount)) {
          case(#Ok(id)) {
              txcounter += 1;
              order.status := #cancel(txcounter);
              ignore storage.addOrder(_toOrderExt(order));
              ignore storage.addRecord(caller, #cancel({orderId = order.index; user = caller; direction = #Buy}), Time.now());
              return #ok(txcounter);
          };
          case(#Err(e)) {
              buys.put(args.index, order);
              switch(listBuyMap.get(order.price)) {
                  case(null) {
                      let orderSet = TrieSet.fromArray([order], Types._hashOfOrder, Types._equalOfOrder);
                      listBuyMap.put(order.price, orderSet);
                  };
                  case(?orderSet) {
                      let newOrderSet = TrieSet.put(orderSet, order, Types._hashOfOrder(order), Types._equalOfOrder);
                      listBuyMap.put(order.price, newOrderSet);
                  };
              };
              if(order.price == listBuyMax) {
                  if(listBuyMax_Number > 0) listBuyMax_Number += 1;
                  if(listBuyMax_Number == 0) {
                      listBuyMax_Number := 1;
                      listBuyMax := order.price;
                  };
              };
              return #err(#TransferFrom_ToUser_Error);
          };
      };
  };

  // 添加公司信息
  public shared({caller}) func addCompany(company: Company): async Bool{
      true
  };

  // 撮合交易
  public shared({caller}) func deal(): async () {

  };

//   // deposit WICP to canister
//   public shared(msg) func deposit(amount: Nat): async TxReceipt {
//       switch(await wicp.transferFrom(msg.caller, Principal.fromActor(this), amount)) {
//           case(#Ok(id)) { };
//           case(#Err(e)) { return #err("deposit fail"); };
//       };
//       let bal = _balanceOf(msg.caller);
//       balances.put(msg.caller, bal + amount);
//       ignore storage.addRecord(msg.caller, #deposit({from = msg.caller; to = Principal.fromActor(this); amount = amount}), Time.now());
//       txcounter += 1;
//       return #ok(txcounter - 1);
//   };

//   // withdraw WICP from canister
//   public shared(msg) func withdraw(amount: Nat): async TxReceipt {
//       let bal = _balanceOf(msg.caller);
//       if (bal < amount)
//           return #err("insufficient balance");
//       balances.put(msg.caller, bal - amount);
//       switch(await wicp.transfer(msg.caller, amount - wicpFee)) {
//           case(#Ok(id)) { 
//               // msg.caller == this canister
//               ignore storage.addRecord(msg.caller, #withdraw({from = Principal.fromActor(this); to = msg.caller; amount = amount}), Time.now());
//               txcounter += 1;
//               return #ok(txcounter - 1);
//           };
//           case(#Err(e)) {
//               // transfer fail, restore user balance
//               balances.put(msg.caller, bal);
//               return #err("withdraw fail");
//           };
//       };
//   };
  
  // 返回[(价格， 数量)] 
  public query({caller}) func getSellList(): async [(Nat, Nat)] {
      [(0,0)]
  };

  public query({caller}) func getBuyList(): async [(Nat, Nat)] {
      [(0,0)]
  };

}