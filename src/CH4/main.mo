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
  stable var sells_entries: [(Nat, Order)] = [];
  stable var buys_entries: [(Nat, Order)] = [];
  stable var companys_entries: [(Principal, Company)] = [];
  stable var listSellIndex = 0;
  stable var listBuyIndex = 0;
  stable var txcounter = 0;
  var sells: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(sells_entries.vals(), Nat.equal, Hash.hash);
  var buys: TrieMap.TrieMap<Nat, Order> = TrieMap.fromEntries<Nat, Order>(buys_entries.vals(), Nat.equal, Hash.hash);
  var companys: TrieMap.TrieMap<Principal, Company> = TrieMap.fromEntries<Principal, Company>(companys_entries.vals(), Principal.equal, Principal.hash);
  var deals = TrieSet.empty<DealOrder>();

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
    //   let sellArray = Array.thaw(Array.sort(Iter.toArray(sells.vals()), Types.orderCompare));
    //   let buyArray = Array.thaw(Array.sort(Iter.toArray(buys.vals()), Types.orderCompare));
    //   var i1 = buyArray.size() - 1;
    //   var i2 = 0;
    //   label l1 loop {
    //       i2 := 0;
    //       for(x in sellArray.vals()) {
    //           if(buyArray[i1].price > x.price) {

    //           }
    //       }
    //   }
    if(sells.size() > 0 and buys.size() > 0) {
        let sellArray = Iter.toArray(sells.vals());
        let buyArray = Iter.toArray(buys.vals());
      switch(await cny.transfer(sellArray[0].owner, sellArray[0].amount * sellArray[0].price)) {
          case(#Ok(id)) {
              switch(await ch4.transfer(buyArray[0].owner, buyArray[0].amount)) {
                  case(#Ok(id)) {
                      let dealOrder = {
                          buyer = buyArray[0].owner;
                          seller = sellArray[0].owner;
                          sellOrderIndex = sellArray[0].index;
                          buyOrderIndex = buyArray[0].index;
                          amount = sellArray[0].amount;
                          price = sellArray[0].price;
                          sum = sellArray[0].amount * sellArray[0].price;
                          dealTime = Time.now();
                      };
                      deals := TrieSet.put(deals, dealOrder, Types._hashOfDealOrder(dealOrder), Types._equalOfDealOrder);
                      sells.delete(sellArray[0].index);
                      buys.delete(buyArray[0].index);
                  };
                  case(#Err(e)) {};
              }
          };
          case(#Err(e)) {};
      };
    }
  };

  public query({caller}) func getDeals(): async [DealOrder] {
      TrieSet.toArray(deals)
  };

    system func heartbeat() : async () {
        let marketActor: MarketActor = actor("ngtm2-tyaaa-aaaan-qahpa-cai");
        await marketActor.deal();
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

//   public shared({caller}) func mintCh4(to: Principal,value: Nat): async Bool{
//       switch(await ch4.mint(to, value)) {
//           case(#Ok(txid)) { true};
//           case(#Err(err)) { false};
//       };
//   };
  
//   public shared({caller}) func burnCh4(who: Principal,amount: Nat): async Result.Result<Bool, Error> {
//       let balance = await ch4.balanceOf(caller);
//       if(balance < amount) { return #err(#Insufficient_CH4);};
//       switch(await ch4.transferFrom(caller, Principal.fromActor(this), amount)) {
//           case(#Ok(id)) { return #ok(true);};
//           case(#Err(e)) { return #err(#TransferFrom_CH4_Error);};
//       }; 
//   };
  
//   public shared({caller}) func ch4BalanceOf(who: Principal): async Nat {
//       let balance = await ch4.balanceOf(who);
//       balance
//   };

//   public shared({caller}) func cnyBalanceOf(who: Principal): async Nat {
//       await cny.balanceOf(who)
//   };

//   public shared({caller}) func mintcny(to: Principal,value: Nat): async Bool{
//       switch(await cny.mint(to, value)) {
//           case(#Ok(txid)) { true};
//           case(#Err(err)) { false};
//       };
//   };

}