import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import TrieSet "mo:base/TrieSet";
import Result "mo:base/Result";
import Iter "mo:base/Iter";

import Types "types";

shared(installer) actor class Sell(admin_ : Principal,cny_: Principal,ch4_: Principal,storage_: Principal) = this {

  public type Error = {
    #Insufficient_cny;
    #Insufficient_CH4;
    #TransferFrom_CH4_Error;
    #Invaild_index;
    #Unauthorized;
    #Order_Not_Open;
    #Change_Old_listSellMap_Error;
    #Transfer_ToUser_Error;
    #TransferFrom_cny_Error;
    #Equal_No_Need_Update;
    //
    #InsufficientBalance;
    #InsufficientAllowance;
    #LedgerTrap;
    #AmountTooSmall;
    #BlockUsed;
    #ErrorOperationStyle;
    #ErrorTo;
    #Other;
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
      mint: shared (to: Principal, value: Nat) -> async TxReceiptToken;
  };

  type StorageActor = actor {
      addRecord: shared (caller: Principal, op: Operation, timestamp: Time.Time) -> async Nat;
      addOrder:  shared (order: OrderExt) -> async Nat;
  };

  type MarketActor = actor {
      deal: shared() -> async ();
  };

  type TxReceipt = Result.Result<Nat, Text>;
  type Operation = Types.Operation;
  type OrderExt = Types.OrderExt;
  type Company = Types.Company;
  type Order = Types.Order;
  type ListArgs = Types.ListArgs;
  type UpdateArgs = Types.UpdateArgs;
  type CancelArgs = Types.CancelArgs;
  type DealOrder = Types.DealOrder;
  private stable let cny: TokenActor = actor(Principal.toText(cny_));
  private stable let ch4: TokenActor = actor(Principal.toText(ch4_));
  private stable let storage: StorageActor = actor(Principal.toText(storage_));
  stable var WarningThreshold: Nat = 10;
  stable var sells_entries: [(Nat, Order)] = [];
  stable var buys_entries: [(Nat, Order)] = [];
  stable var companys_entries: [(Principal, Company)] = [];
  stable var fromBuy_entries: [(Principal, Nat)] = [];
  stable var toSell_entries: [(Principal, Nat)] = [];
  stable var listSellIndex = 0;
  stable var listBuyIndex = 0;
  stable var txcounter = 0;
  stable var deals = TrieSet.empty<DealOrder>();
  var fromBuy: TrieMap.TrieMap<Principal, Nat> = TrieMap.fromEntries<Principal, Nat>(fromBuy_entries.vals(), Principal.equal, Principal.hash);
  var toSell: TrieMap.TrieMap<Principal, Nat> = TrieMap.fromEntries<Principal, Nat>(toSell_entries.vals(), Principal.equal, Principal.hash);
  var sells: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(sells_entries.vals(), Nat.equal, Hash.hash);
  var buys: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(buys_entries.vals(), Nat.equal, Hash.hash);
  var companys: TrieMap.TrieMap<Principal, Company> = TrieMap.fromEntries<Principal, Company>(companys_entries.vals(), Principal.equal, Principal.hash);

  // 挂出售单 价格 与 接受价格下调幅度
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将ch4转到平台账户
  // 创建一个Order订单
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
          owner = caller;
          var amount = args.amount;
          var price = args.price;
          var delta = args.delta;
          var status = #open(txcounter);
          createAt = Time.now();
      };
      sells.put(listSellIndex, order);
      ignore storage.addRecord(caller, #list({orderId = order.index; user = caller; price = args.price; amount = args.amount; direction = #Sell;}), Time.now());
      return #ok(order.index);
  };

  public shared({caller}) func updateSell(
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
      if(order.price == args.newPrice and order.delta == args.newDelta and order.amount == args.newAmount)
          {return #err(#Equal_No_Need_Update);};
      if(args.newAmount < order.amount) {
          switch(await ch4.transfer(caller, (order.amount - args.newAmount))) {
              case(#Ok(id)) {};
              case(#Err(e)) { return #err(#Transfer_ToUser_Error);};
          };
      } else if(args.newAmount > order.amount) {
          switch(await ch4.transferFrom(caller, Principal.fromActor(this), (args.newAmount - order.amount))) {
              case(#Ok(id)) {};
              case(#Err(e)) { return #err(#TransferFrom_CH4_Error);};
          };
      };
      order.amount := args.newAmount;
      order.price := args.newPrice;
      order.delta := args.newDelta;
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
      switch(await ch4.transfer(caller, order.amount)) {
          case(#Ok(id)) {
              txcounter += 1;
              order.status := #cancel(txcounter);
              ignore storage.addOrder(_toOrderExt(order));
              ignore storage.addRecord(caller, #cancel({orderId = order.index; user = caller; direction = #Sell}), Time.now());
              return #ok(txcounter);
          };
          case(#Err(e)) {
              sells.put(args.index, order);
              return #err(#Transfer_ToUser_Error);
          };
      };
  };

  // 限价挂买入单
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将wicp转到平台账户
  // 创建一个Order订单
  // Tx记录
  public shared({caller}) func listBuy(
      args: ListArgs
  ): async Result.Result<Nat, Error> {
      let balance = await cny.balanceOf(caller);
      let needBalance = args.amount * (args.price + args.delta);
      if(balance < needBalance) { return #err(#Insufficient_cny);};
      switch(await cny.transferFrom(caller, Principal.fromActor(this), needBalance)) {
          case(#Ok(id)) {};
          case(#Err(e)) { return #err(e);};
      }; 
      listBuyIndex += 1;
      txcounter += 1;
      let order: Order = {
          index = listBuyIndex;
          owner = caller;
          var amount = args.amount;
          var price = args.price;
          var delta = args.delta;
          var status = #open(txcounter);
          createAt = Time.now();
      };
      buys.put(listBuyIndex, order);
      ignore storage.addRecord(caller, #list({orderId = order.index; user = caller; price = args.price; amount = args.amount; direction = #Buy;}), Time.now());
      return #ok(order.index);
  };

  public shared({caller}) func updateBuy(
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
      if(order.price == args.newPrice and order.delta == args.newDelta and order.amount == args.newAmount)
          return #err(#Equal_No_Need_Update);
      let newNeedBalance = args.newAmount * (args.newPrice + args.newDelta);
      let balance = order.amount * (order.price + order.delta);
      if(newNeedBalance < balance) {
          switch(await cny.transfer(caller, (balance - newNeedBalance))) {
            case(#Ok(id)) {};
            case(#Err(e)) { return #err(#Transfer_ToUser_Error);};
          };  
      } else if(newNeedBalance > balance) {
          switch(await cny.transferFrom(caller, Principal.fromActor(this), (newNeedBalance - balance))) {
              case(#Ok(id)) {};
              case(#Err(e)) { return #err(#TransferFrom_cny_Error);};
          };
      };
      order.amount := args.newAmount;
      order.delta := args.newDelta;
      order.price := args.newPrice;
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
      let needBalance = order.amount * (order.price + order.delta);
      switch(await cny.transfer(caller, needBalance)) {
          case(#Ok(id)) {
              txcounter += 1;
              order.status := #cancel(txcounter);
              ignore storage.addOrder(_toOrderExt(order));
              ignore storage.addRecord(caller, #cancel({orderId = order.index; user = caller; direction = #Buy}), Time.now());
              return #ok(txcounter);
          };
          case(#Err(e)) {
              buys.put(args.index, order);
              return #err(#Transfer_ToUser_Error);
          };
      };
  };

  public shared({caller}) func warning(): async Text {
    let balance = await ch4.balanceOf(caller);
    if(balance <= WarningThreshold) {
        return "Your CH4 balance is about to be low, please deal with it in time"
    };
    "sufficient CH4 balance"
  };

  public query({caller}) func getSellList(): async [OrderExt] {
      let pre_ans= (Iter.toArray(sells.vals()));
      let ans = Array.init<OrderExt>(pre_ans.size(), {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });
      var i = 0;
      for(x in pre_ans.vals()) {
          ans[i] := _toOrderExt(x);
          i += 1;
      };
      Array.freeze<OrderExt>(ans)
  };

  public query({caller}) func getBuyList(): async [OrderExt] {
      let pre_ans= (Iter.toArray(buys.vals()));
      let ans = Array.init<OrderExt>(pre_ans.size(), {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });
      var i = 0;
      for(x in pre_ans.vals()) {
          ans[i] := _toOrderExt(x);
          i += 1;
      };
      Array.freeze<OrderExt>(ans)
  };
  
  public query({caller}) func getSomebodySellList(user: Principal): async [OrderExt] {
      let pre_ans= (Iter.toArray(sells.vals()));
      let _ans = Array.init<OrderExt>(pre_ans.size(), {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });
      var i = 0;
      for(x in pre_ans.vals()) {
          if(x.owner == user) {
            _ans[i] := _toOrderExt(x);
            i += 1;
          };
      };
      let ans = Array.init<OrderExt>(i+1, {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });      
      i := 0;
      for(x in _ans.vals()) {
         ans[i] := x;
         i += 1;
      };      
      Array.freeze<OrderExt>(ans)    
  };

  public query({caller}) func getSomebodyBuyList(user: Principal): async [OrderExt] {
      let pre_ans= (Iter.toArray(buys.vals()));
      let _ans = Array.init<OrderExt>(pre_ans.size(), {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });
      var i = 0;
      for(x in pre_ans.vals()) {
          if(x.owner == user) {
            _ans[i] := _toOrderExt(x);
            i += 1;
          };
      };
      let ans = Array.init<OrderExt>(i+1, {
          index = 0;
          owner = Principal.fromText("aaaaa-aa");
          amount = 0;
          delta = 0;
          price = 0;
          status = #open(0);
          createAt = 0;
      });      
      i := 0;
      for(x in _ans.vals()) {
         ans[i] := x;
         i += 1;
      };      
      Array.freeze<OrderExt>(ans)    
  };
  
  // 添加公司信息
  public shared({caller}) func addCompany(company: Company): async Bool{
      companys.put(caller, company);
      true
  };

  // 撮合交易
  public shared({caller}) func deal(): async () {
    if(sells.size() > 0 and buys.size() > 0) {
        var i1 = 0; 
        var i2 = 0;
        let buyArray = Array.sort(Iter.toArray(buys.vals()), Types.orderCompare);
        let sellArray = Array.sort(Iter.toArray(sells.vals()), Types.orderCompare);

        label l1 for(x1 in buyArray.vals()) {
            label l2 for(x2 in sellArray.vals()) {
                if(x2.price > x1.price) { break l2};
                if(x1.price == x2.price) {
                    var buyAmount = 0;
                    switch(buys.get(x1.index)) {
                        case(null) { break l2;};
                        case(?buyOrder) {
                            buyAmount := buyOrder.amount;
                            if(buyAmount == 0) break l2;
                        };
                    };
                    var sellAmount = 0;
                    switch(sells.get(x2.index)) {
                        case(null) {continue l2};
                        case(?sellOrder) {
                            sellAmount := sellOrder.amount;
                            if(sellAmount == 0) continue l2;
                        };
                    };
                    let dealAmount = if(buyAmount <= sellAmount) { buyAmount } else { sellAmount };
                    // 转ch4给买家
                    switch(await ch4.transfer(x1.owner, dealAmount)) {
                        case(#Ok(id)) {};
                        case(#Err(e)) {};
                    };
                    switch(await cny.transfer(x2.owner, dealAmount * x1.price)) {
                        case(#Ok(id)) {};
                        case(#Err(e)) {};
                    };
                    if((buyAmount - dealAmount) > 0) {
                        switch(buys.get(x1.index)) {
                            case(null) {};
                            case(?buyOrder) {
                                buyOrder.amount -= dealAmount;
                                buys.put(x1.index, buyOrder);
                            };
                        };
                    } else { buys.delete(x1.index);};
                    if((sellAmount - dealAmount) > 0) {
                        switch(sells.get(x2.index)) {
                            case(null) {};
                            case(?sellOrder) {
                                sellOrder.amount -= dealAmount;
                                sells.put(x2.index, sellOrder);
                            };
                        };
                    } else { sells.delete(x2.index);};
                    // 
                    let fromBuy_balance = _fromBuy_balanceOf(x1.owner);
                    fromBuy.put(x1.owner, dealAmount);
                    let toSell_balance = _toSell_balanceOf(x2.owner);
                    toSell.put(x2.owner, dealAmount);
                    let dealOrder: DealOrder = {
                        buyer = x1.owner;
                        seller = x2.owner;
                        sellOrderIndex = x2.index;
                        buyOrderIndex = x1.index;
                        amount = dealAmount;
                        price = x1.price;
                        sum = dealAmount * x1.price;
                        dealTime = Time.now();
                    };
                    deals := TrieSet.put(deals, dealOrder, Types._hashOfDealOrder(dealOrder), Types._equalOfDealOrder);
                };
            }
        }
    }
  };

  public shared({caller}) func addDeals(
    args: DealOrder
  ): async Bool {
    deals := TrieSet.put(deals, args, Types._hashOfDealOrder(args), Types._equalOfDealOrder);
    true
  };

  public query({caller}) func getTImeNow(): async Int {
    Time.now()
  };

  public query({caller}) func getDeals(): async [DealOrder] {
      TrieSet.toArray(deals)
  };

    public query func fromBuy_balanceof(who: Principal): async Nat {
        _fromBuy_balanceOf(who)
    };

    public query func toSell_balanceof(who: Principal): async Nat {
        _toSell_balanceOf(who)
    };

  public query({caller}) func getRecentMonthDeals(): async [DealOrder] {
      let pre_ans = TrieSet.toArray(deals);
      let _ans = Array.init<DealOrder>(pre_ans.size(), {
        buyer = Principal.fromText("aaaaa-aa");
        seller = Principal.fromText("aaaaa-aa");
        index = 0;
        owner = Principal.fromText("aaaaa-aa");
        sellOrderIndex = 0;
        buyOrderIndex = 0;
        amount = 0;
        price = 0;
        sum = 0;
        dealTime = 0;
      });
      let Time_LIMIT: Int = 2_592_000_000_000_000;
      let now = Time.now();
      var i = 0;
      for(x in pre_ans.vals()) {
          if((now - x.dealTime) <= Time_LIMIT) {
            _ans[i] := x;
            i += 1;
          };
      };
      let ans = Array.init<DealOrder>(_ans.size(), {
        buyer = Principal.fromText("aaaaa-aa");
        seller = Principal.fromText("aaaaa-aa");
        index = 0;
        owner = Principal.fromText("aaaaa-aa");
        sellOrderIndex = 0;
        buyOrderIndex = 0;
        amount = 0;
        price = 0;
        sum = 0;
        dealTime = 0;
      });   
      i := 0;
      for(x in _ans.vals()) {
         ans[i] := x;
         i += 1;
      };      
      Array.freeze<DealOrder>(ans)    
  };

  system func preupgrade() {
    sells_entries := Iter.toArray(sells.entries());
    buys_entries := Iter.toArray(buys.entries());
    companys_entries := Iter.toArray(companys.entries());
    fromBuy_entries := Iter.toArray(fromBuy.entries());
    toSell_entries := Iter.toArray(toSell.entries());
  };

  system func postupgrade() {
    sells_entries := [];
    buys_entries := [];
    companys_entries := [];
    fromBuy_entries := [];
    toSell_entries := [];
  };
  
  system func heartbeat(): async () {
    let marketActor: MarketActor = actor("ngtm2-tyaaa-aaaan-qahpa-cai");
    await marketActor.deal();
  };


    private func _fromBuy_balanceOf(who: Principal): Nat {
        switch(fromBuy.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };
    private func _toSell_balanceOf(who: Principal): Nat {
        switch(toSell.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

  private func _toOrderExt(order: Order): OrderExt {
      {
          index = order.index;
          amount = order.amount;
          owner = order.owner;
          price = order.price;
          delta = order.delta;
          status = order.status;
          createAt = order.createAt;
      }
  };

}