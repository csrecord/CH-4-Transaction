
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
        amount: Nat;
        user: Principal;
        var price: Nat;
        var status: OrderStatus;
        createAt: Int;
    };
};    

