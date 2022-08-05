import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";

// chưa có cơ chế stable (khi triển khai thực tế phải thêm vào)
actor Uniswap{
    // Lưu ý trong các hàm có param value thì value ấy tương đương vs số lượng ICP được truyền đến canister khi gọi hàm đó, cho nên 
    // khi triển khai thực tế phải có thêm cơ chế truyền nhận ICP

    let FEE_RATE : Nat = 500; //fee = 1/feeRate = 0.2%

    private var this : Principal = Principal.fromText(""); // principal of this canister
    private var ethPool : Nat = 0;
    private var tokenPool : Nat = 0;
    private var invariant : Nat = 0;
    private var totalShares : Nat = 0;

    private var shares = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    type TokenService = actor{  transfer : (_to : Principal, _value : Nat) -> async Bool;
                                transferFrom : (_from : Principal, _to : Principal, _value : Nat) -> async Bool;
                                approve : (_spender: Principal, _value: Nat) -> async Bool;
                                balanceOf : (_who: Principal) -> async Nat;
                                allowance : (_owner: Principal, _spender: Principal) -> async Nat;
                             };
    private var token : TokenService = actor(""); // principal of ERC20Token canister

    public shared({caller}) func initializeExchange(value : Nat, _tokenAmount : Nat) : async () {
        assert(invariant == 0 and totalShares == 0);
        assert(value >= 10000 and _tokenAmount >= 10000 and value <= 5*10**18);
        ethPool := value;
        tokenPool := _tokenAmount;
        invariant := ethPool * tokenPool;
        shares.put(caller, 1000);
        totalShares := 1000;
        assert(await token.transferFrom(caller, this, _tokenAmount));
    };

    // Buyer swaps ETH for Tokens
    public shared({caller}) func ethToTokenSwap(value : Nat, _minTokens : Nat) : async (){
        assert(value > 0 and _minTokens > 0);
        await ethToToken(caller, caller, value, _minTokens);
    };

    // Payer pays in ETH, recipient receives Tokens
    public shared({caller}) func ethToTokenPayment(value : Nat, _minTokens : Nat, _recipient : Principal) : async () {
        assert(value > 0 and _minTokens > 0);
        await ethToToken(caller, _recipient, value, _minTokens);
    };

    // Buyer swaps Tokens for ETH
    public shared({caller}) func tokenToEthSwap(_tokenAmount : Nat, _minEth : Nat) : async (){
        assert(_tokenAmount > 0 and _minEth > 0);
        await tokenToEth(caller, caller, _tokenAmount, _minEth);
    };

    // Payer pays in Tokens, recipient receives ETH
    public shared({caller}) func tokenToEthPayment(_tokenAmount : Nat, _minEth : Nat, _recipient : Principal) : async () {
        assert(_tokenAmount  > 0 and _minEth  > 0);
        await ethToToken(caller, _recipient, _tokenAmount, _minEth);
    };

    // Invest liquidity and receive market shares
    public shared({caller}) func investLiquidity(value : Nat, _minShares : Nat) : async () {
        assert(value > 0 and _minShares > 0);
        var ethPerShare : Nat = ethPool / totalShares;
        assert(value > ethPerShare);
        var sharesPurchased : Nat = value / ethPerShare;
        assert(sharesPurchased >= _minShares);
        var tokensPerShare : Nat = tokenPool / totalShares;
        var tokensRequired : Nat = sharesPurchased * tokensPerShare;
         
        switch(shares.get(caller)){
            case(null){
                shares.put(caller, sharesPurchased);
            };
            case(?n){
                shares.put(caller, n + sharesPurchased);
            };
        };

        totalShares := totalShares + sharesPurchased;
        ethPool := ethPool + value;
        tokenPool := tokenPool + tokensRequired;
        invariant := ethPool * tokenPool;
    };

    // Divest market shares and receive liquidity
    public shared({caller}) func divestLiquidity(_sharesBurned : Nat, _minEth : Nat, _minTokens : Nat) : async () {
        assert(_sharesBurned > 0);
        switch(shares.get(caller)){
            case(null){
                return;
            };
            case(?n){
                shares.put(caller, n - _sharesBurned);
            };
        };
        var ethPerShare : Nat = ethPool / totalShares;
        var tokensPerShare : Nat = tokenPool / totalShares;
        var ethDivested : Nat = ethPerShare * _sharesBurned;
        var tokensDivested : Nat = tokensPerShare * _sharesBurned;
        assert(ethDivested >= _minEth and tokensDivested >= _minTokens);
        totalShares := totalShares - _sharesBurned;
        ethPool := ethPool - ethDivested;
        tokenPool := tokenPool - tokensDivested;
        if(totalShares == 0){
           invariant := 0; 
        } else{
            invariant := ethPool * tokenPool;
        }
        //tranferEth(caller, ethDivested) trong trường hợp ICP là hàm để chuyển "ICP" từ canister đến caller
    };

    public func getShares(_provider : Principal) : async ?Nat {
        return shares.get(_provider);
    };


    private func ethToToken(buyer : Principal, recipient : Principal, ethIn : Nat, minTokensOut: Nat) : async () {
        var fee : Nat = ethIn / FEE_RATE;
        var newEthPool : Nat = ethPool + ethIn;
        var tempEthPool : Nat = newEthPool - fee;
        var newTokenPool : Nat = invariant / tempEthPool;
        var tokensOut : Nat = tokenPool - newTokenPool;
        assert (tokensOut >= minTokensOut and tokensOut <= tokenPool);
        ethPool := newEthPool;
        tokenPool := newTokenPool;
        invariant := newEthPool * newTokenPool; 
        assert(await token.transfer(recipient, tokensOut));
    };

    private func tokenToEth(buyer : Principal, recipient : Principal, tokensIn : Nat, minEthOut: Nat) : async () {
        var fee : Nat = tokensIn / FEE_RATE;
        var newTokenPool : Nat = tokenPool + tokensIn;
        var tempTokenPool : Nat = newTokenPool - fee;
        var newEthPool : Nat = invariant / tempTokenPool;
        var ethOut : Nat = ethPool - newEthPool;
        assert(ethOut >= minEthOut and ethOut <= ethPool);
        tokenPool := newTokenPool;
        ethPool := newEthPool;
        invariant := newEthPool * newTokenPool;
        assert(await token.transferFrom(buyer, this, tokensIn));
        // tranferEth(recipient, ethOut) // trong trường hợp ICP là hàm để chuyển "ICP" từ canister đến recipient
    };
} 