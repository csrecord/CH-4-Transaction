import Array "mo:base/Array";

shared(installer) actor class Sell(admin_ : Principal,wicp_: Principal,ch4_: Principal) = this {

  public type Error = {
    #Insufficient_money;
    #Insufficient_CH4;
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
  
  private stable var wicp: TokenActor = actor(Principal.toText(wicp_));
  private stable var ch4: TokenActor = actor(Principal.toText(ch4_));
  let listSellArray: [var Nat] = Array.init<Nat>(50010,0);
  let listBuyArray:  [var Nat] = Array.init<Nat>(50010,0);



  // 限价挂出售单
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将ch4转到平台账户
  // 创建一个Order订单
  // 
  // Tx记录
  public shared({caller}) func listSell(): async Result.Result<(),Error> {

  };

  // 限价挂买入单
  // 在ch4 canister查询余额够不够，不够就#Insufficient_CH4
  // 够的话先将ch4转到平台账户
  // 创建一个Order订单
  // Tx记录
  public shared({caller}) func listBuy(): async Result.Result {

  };

  public shared({caller}) func addCompany(company: Company): async Bool{

  };
  
  // deposit WICP to canister
  public shared(msg) func deposit(amount: Nat): async TxReceipt {
      switch(await wicp.transferFrom(msg.caller, Principal.fromActor(this), amount)) {
          case(#Ok(id)) { };
          case(#Err(e)) { return #err("deposit fail"); };
      };
      let bal = _balanceOf(msg.caller);
      balances.put(msg.caller, bal + amount);
      ignore storage.addRecord(msg.caller, #deposit({from = msg.caller; to = Principal.fromActor(this); amount = amount}), Time.now());
      txcounter += 1;
      return #ok(txcounter - 1);
  };

  // withdraw WICP from canister
  public shared(msg) func withdraw(amount: Nat): async TxReceipt {
      let bal = _balanceOf(msg.caller);
      if (bal < amount)
          return #err("insufficient balance");
      balances.put(msg.caller, bal - amount);
      switch(await wicp.transfer(msg.caller, amount - wicpFee)) {
          case(#Ok(id)) { 
              // msg.caller == this canister
              ignore storage.addRecord(msg.caller, #withdraw({from = Principal.fromActor(this); to = msg.caller; amount = amount}), Time.now());
              txcounter += 1;
              return #ok(txcounter - 1);
          };
          case(#Err(e)) {
              // transfer fail, restore user balance
              balances.put(msg.caller, bal);
              return #err("withdraw fail");
          };
      };
  };
}