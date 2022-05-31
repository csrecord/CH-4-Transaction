import Hash "mo:base/Hash";

module {
    
    public type Company = {
        name: Text;
        desc: Text;
        webLink: Text;
        principal: Principal;
    };
    
    public type OrderStatus = {
        #open: Nat; // list tx id
        #cancel: Nat; // cancel tx id
        #done: Nat; // buy tx id
    };
    
    public type Order = {
        index: Nat;
        owner: Principal;
        var amount: Nat;
        var delta: Nat; //接受多少差价
        var price: Nat;
        var status: OrderStatus;
        createAt: Int;
    };

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

    public type OrderExt = {
        index: Nat;
        owner: Principal;
        amount: Nat;
        delta: Nat; //接受多少差价
        price: Nat;
        status: OrderStatus;
        createAt: Int;
    };

    public type PriceInfo = {
        date: Int;
        avg: Nat;
        volume: Nat;
        num: Nat;
        min: Nat;
        max: Nat;
    };
    public type ItemInfo = {
        id: Nat;
        price: Nat;
        from: Principal;
        to: Principal;
        time: Int;
    };
    public type ListArgs = {
        amount: Nat;
        price: Nat;
        delta: Nat;
    };

    public type UpdateArgs = {
        index: Nat;
        newAmount: Nat;
        newPrice: Nat;
        newDelta: Nat;
    };

    public type CancelArgs = {
        index: Nat;
    };

    public type Direction = {
        #Buy;
        #Sell;
    };

    public type Operation = {
        #deposit : {
            from: Principal;
            to: Principal;
            amount: Nat;
        };
        #withdraw : {
            from: Principal;
            to: Principal;
            amount: Nat;
        };
        #list : {
            orderId: Nat;
            user: Principal;
            price: Nat;
            amount: Nat;
            direction: Direction;
        };
        #cancel : {
            orderId: Nat;
            user: Principal;
            direction: Direction;
        };
        #deal : {
            orderId: Nat;
            seller: Principal;
            buyer: Principal;
            price: Nat;
            amount: Nat;
        };
    };

    public type TxRecord = {
        index: Nat;
        op: Operation;
        timestamp: Int;
    };
    


    public func _hashOfOrder(
        order: Order
    ): Hash.Hash{
        Hash.hash(order.index)
    };

    public func _equalOfOrder(
        a: Order,b: Order
    ): Bool{
        a.index == b.index and a.price == b.price
    };

    public func _hashOfDealOrder(
        order: DealOrder
    ): Hash.Hash{
        Hash.hash(order.sellOrderIndex)
    };

    public func _equalOfDealOrder(
        a: DealOrder,b: DealOrder
    ): Bool{
        a.sellOrderIndex == b.sellOrderIndex and a.buyOrderIndex == b.buyOrderIndex
    };
    
    // public type Order = {
    //     index: Nat;
    //     owner: Principal;
    //     var amount: Nat;
    //     var delta: Nat; //接受多少差价
    //     var price: Nat;
    //     var status: OrderStatus;
    //     createAt: Int;
    // };

    public func orderCompare(x: Order, y: Order) : {#less; #equal; #greater} {
        if(x.price < y.price) { #less }
        else if(x.price == y.price) { #equal }
        else { #greater}
    };

    
};    

