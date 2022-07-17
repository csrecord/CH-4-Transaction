- 卖方挂单

```
public shared({caller}) func listSell(
      args: ListArgs
  ): async Result.Result<Nat, Error>
  
      public type ListArgs = {
        amount: Nat;
        price: Nat;
        delta: Nat;
    };
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
```

- 卖方更改挂单

```
public shared({caller}) func updateSell(
      args: UpdateArgs
  ): async Result.Result<Bool, Error>
  
      public type UpdateArgs = {
        index: Nat;
        newAmount: Nat;
        newPrice: Nat;
        newDelta: Nat;
    };
```

- 卖方取消挂单

```
public shared({caller}) func cancelSell(
      args: CancelArgs
  ): async Result.Result<Nat, Error>
  
      public type CancelArgs = {
        index: Nat;
    };
```

- 买方挂单

```
public shared({caller}) func listBuy(
      args: ListArgs
  ): async Result.Result<Nat, Error>
```

- 买方更改挂单

```
public shared({caller}) func updateBuy(
      args: UpdateArgs
  ): async Result.Result<Bool, Error>
```

- 买方取消挂单

```
public shared({caller}) func cancelBuy(
      args: CancelArgs
  ): async Result.Result<Nat, Error>
```

- 获取卖方挂单列表

```
public query({caller}) func getSellList(): async [OrderExt]

    public type OrderExt = {
        index: Nat;
        owner: Principal;
        amount: Nat;
        delta: Nat; //接受多少差价
        price: Nat;
        status: OrderStatus;
        createAt: Int;
    };
```

- 买方挂单列表

```
public query({caller}) func getBuyList(): async [OrderExt]
```

- 获取成交列表

```
public query({caller}) func getDeals(): async [DealOrder]

    public type DealOrder = {
        buyer: Principal;
        seller: Principal;
        sellOrderIndex: Nat;
        buyOrderIndex: Nat;
        amount: Nat;
        price: Nat;
        sum: Nat;
        dealTime: Int;
    };
```

- 获取一个用户总共被政府派发的额度 -> CH4 Canister

  ```
      public query func minted_balanceof(who: Principal): async Nat {
          _minted_balanceOf(who)
      };
  ```

  

- 获取一个用户燃烧排放的额度 -> CH4 Canister

  ```
      public query func burned_balanceof(who: Principal): async Nat {
          _burned_balanceOf(who)
      };
  ```

- 获取一个用户自己购入的总额度 -> market Canister

  ```
      public query func fromBuy_balanceof(who: Principal): async Nat {
          _fromBuy_balanceOf(who)
      };
  ```

- 获取一个用户自己卖出的总额度 -> market canister

  ```
      public query func toSell_balanceof(who: Principal): async Nat {
          _toSell_balanceOf(who)
      };
  ```

  
