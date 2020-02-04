pragma solidity ^0.5.0.0;


library SafeMath {

    // +
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    // -
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    // *
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    // /
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    // %
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}



contract Vr{

    

    address public owner;
    mapping (address => bool) admins;

    //初始化

    //modidiers
    modifier onlyOwner() {
        require(isOwner(), "AdminBase: caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "AdminBase caller is not an admin");
        _;
    }

    //判断是否为拥有者
    function isOwner() public view returns(bool) {
        return msg.sender == owner;
    }
    //判断是否为管理员
    function isAdmin() public view returns(bool) {
        return admins[msg.sender];
    }
    //添加管理员
    function addAdmin(address account) public onlyOwner{
        admins[account] = true;
    }
    //删除管理员
    function removeAdmin(address account) public onlyOwner{
        admins[account] = false;
    }
    //转移拥有者
    function transferOwner(address account) public onlyOwner {
        owner = account;
    }




    
    using SafeMath for uint;
    
    struct Player {
        address self;
        address parent;
        uint bonus;
        uint totalBonus;
        uint invest;
        uint sons;
        uint round;
        uint index;
    }

    struct Investment {
        address self;
        uint amount;
        uint time;
        uint round;
        bool firstFlag;
    }

    event logLucky(address indexed target, uint money, uint timestamp, uint types);

    event logUserInvest(address indexed playerAddress, address indexed parentAddress, bool firstFlag, uint money, uint timestamp);

    event logWithDraw(address indexed playerAddress, uint money, uint timestamp);

    event logGlory(address indexed playerAddress, uint money, uint timestamp);
    
    address payable constant public ZERO_ADDR = address(0x00);
    uint public _dailyInvest = 0;
    uint public _staticPool = 0;
    uint public _outInvest = 0;
    uint public _safePool = 0;
    uint public _gloryPool = 0;
    mapping(address => Player) allPlayers;
    address[] public allAddress = new address[](0);
    uint[] public lockedRound = new uint[](0);
    uint investCount = 0;
    mapping(uint => Investment) investments;
    address[] public dailyPlayers = new address[](0);
    uint _rand = 88;
    uint _safeIndex = 0;
    uint _endTime = 0;
    uint _startTime = 0;
    bool public _active = true;

    constructor() public {
        owner = msg.sender;
        admins[msg.sender] = true;
        
        
        allPlayers[ZERO_ADDR] = Player({
            self : ZERO_ADDR,
            parent : ZERO_ADDR,
            bonus : 0,
            totalBonus : 0,
            invest : 0,
            sons : 0,
            round: 0,
            index: 0
        });
        lockedRound.push(0);
        allAddress.push(ZERO_ADDR);
        investments[investCount] =  Investment(ZERO_ADDR,0,now,0,true);
        investCount = investCount.add(1);
    }

    function () external payable {
        if(msg.value > 0){
            invest(ZERO_ADDR);
        }else{
            withdraw();
        }
    }

    function invest(address payable parentAddr) public payable {
        require(msg.value >= 0.5 ether && msg.sender != parentAddr, "Parameter Error.");
        require(isStart(), "Game Start Limit");
        require(_active, "Game Over");
        bool isFirst = false;
        if(allPlayers[msg.sender].index == 0){
            isFirst = true;
            Player memory parent = allPlayers[parentAddr];
            if(parent.index == 0) {
                parentAddr = ZERO_ADDR;
            }
            allPlayers[msg.sender] = Player({
                self : msg.sender,
                parent : parentAddr,
                bonus: 0,
                totalBonus : 0,
                invest : msg.value,
                sons : 0,
                round: lockedRound.length,
                index: allAddress.length
            });
            allAddress.push(msg.sender);
        }else{
            Player storage user = allPlayers[msg.sender];
            uint totalBonus = 0;
            uint bonus = 0;
            bool outFlag;
            (totalBonus, bonus, outFlag) = calcBonus(user.self);
            if(outFlag) {
                user.bonus = bonus;
                user.totalBonus = 0;
                user.invest = msg.value;
            }else{
                user.invest = user.invest.add(msg.value);
                user.bonus = bonus;
                user.totalBonus = totalBonus;
            }
            user.round = lockedRound.length;
        }
        _dailyInvest = _dailyInvest.add(msg.value);
        _safePool = _safePool.add(msg.value.div(20));
        _gloryPool = _gloryPool.add(msg.value.mul(3).div(25));
        _staticPool = _staticPool.add(msg.value.mul(9).div(20));
        dailyPlayers.push(msg.sender);
        Player memory self = allPlayers[msg.sender];
        Player memory parent = allPlayers[self.parent];
        uint parentVal = msg.value.div(10);
        if(isFirst == true) {
            investBonus(parent.self, parentVal, true, 1);
        } else {
            investBonus(parent.self, parentVal, true, 0);
        }
        Player memory grand = allPlayers[parent.parent];
        if(grand.sons >= 2){
            uint grandVal = msg.value.div(20);
            investBonus(grand.self, grandVal, true, 0);
        }
        Player memory great = allPlayers[grand.parent];
        if(allPlayers[great.self].sons >= 3){
            uint greatVal = msg.value.div(20);
            investBonus(great.self, greatVal, true, 0);
        }
        Player memory greatFather = allPlayers[great.parent];
        if(allPlayers[greatFather.self].sons >= 4){
            uint superVal = msg.value.mul(3).div(100);
            investBonus(greatFather.self, superVal, true, 0);
        }
        Player memory greatGrandFather = allPlayers[greatFather.parent];
        if(allPlayers[greatGrandFather.self].sons >= 5){
            uint hyperVal = msg.value.div(50);
            investBonus(greatGrandFather.self, hyperVal, true, 0);
        }
        investments[investCount] = Investment(msg.sender,msg.value,now,lockedRound.length,isFirst);
        investCount=investCount.add(1);
        emit logUserInvest(msg.sender, parentAddr, isFirst, msg.value, now);
    }

    function calcBonus(address target) public view returns(uint, uint, bool) {
        Player memory player = allPlayers[target];
        uint lockedBonus = calcLocked(target);
        uint totalBonus = player.totalBonus.add(lockedBonus);
        bool outFlag = false;
        uint less = 0;
        uint maxIncome = 0;
        if(player.invest <= 10 ether){
            maxIncome = player.invest.mul(2);
        }else if(player.invest > 10 ether && player.invest <= 20 ether){
            maxIncome = player.invest.mul(3);
        }else if(player.invest > 20 ether){
            maxIncome = player.invest.mul(5);
        }
        if (totalBonus >= maxIncome) {
            less = totalBonus.sub(maxIncome);
            outFlag = true;
        }
        totalBonus = totalBonus.sub(less);
        uint bonus = player.bonus.add(lockedBonus).sub(less);

        return (totalBonus, bonus, outFlag);
    }

    function calcLocked(address target) public view returns(uint) {
        Player memory self = allPlayers[target];
        uint randTotal = 0;
        for(uint i=self.round; i<lockedRound.length; i++){
            randTotal = randTotal.add(lockedRound[i]);
        }
        uint lockedBonus = self.invest.mul(randTotal).div(10000);
        return lockedBonus;
    }

    function sendGloryAward(address[] memory plays, uint[] memory selfAmount, uint totalAmount)
    public onlyAdmin() {
        _gloryPool = _gloryPool.sub(totalAmount);
        for(uint i = 0; i < plays.length; i++){
            investBonus(plays[i], selfAmount[i], true, 0);
            emit logGlory(plays[i], selfAmount[i], now);
        }
    }

    function lottery() internal {
        uint luckNum = dailyPlayers.length;
        if (luckNum >= 10) {
            luckNum = 10;
        }
        address[] memory luckyDogs = new address[](luckNum);
        uint[] memory luckyAmounts = new uint[](luckNum);
        if (luckNum <= 10) {
            for(uint i=0; i<luckNum; i++) {
                luckyDogs[i] = dailyPlayers[i];
            }
        } else {
            for(uint i= 0; i<luckNum; i++){
                uint random = getRandom(dailyPlayers.length);
                luckyDogs[i] = dailyPlayers[random];
                delete dailyPlayers[random];
            }
        }
        uint totalRandom = 0;
        for(uint i=0; i<luckNum; i++){
            luckyAmounts[i] = getRandom(50).add(1);
            totalRandom = totalRandom.add(luckyAmounts[i]);
        }
        uint lotteryAmount = 0;
        uint luckyPool = _dailyInvest.div(100);
        for(uint i=0; i<luckNum; i++){
            lotteryAmount = luckyAmounts[i].mul(luckyPool).div(totalRandom);
            investBonus(luckyDogs[i], lotteryAmount, false ,0);
            emit logLucky(luckyDogs[i], lotteryAmount, now, 1);
        }
    }

    function fund() internal {
        address payable fundAddr = address(0xE6369df7A8a9A4d0bD8Da06b2E10303AB083FD83);
        if(_dailyInvest > 0) {
            fundAddr.transfer(_dailyInvest.div(10));
        }
    }


    function querySafety(address target) public view returns(uint) {
        uint amount = 0;
        for (uint i = investCount-2; i >= _safeIndex; i--){
            if(investments[i].self == target) {
                amount = amount.add(investments[i].amount);
            }
        }
        return amount;
    }

    function withdraw() public {
        require(isStart(), "Game Start Limit");
        Player storage user = allPlayers[msg.sender];
        uint totalBonus = 0;
        uint withdrawBonus = 0;
        bool outFlag;
        (totalBonus, withdrawBonus, outFlag) = calcBonus(user.self);

        uint safety = 0;
        if(!_active && user.invest>0) {
            safety = querySafety(msg.sender);
            user.invest = 0;
        }
        
        if(outFlag) {
            _outInvest = _outInvest.add(user.invest);
            user.totalBonus = 0;
            user.invest = 0;
        }else {
            user.totalBonus = totalBonus;
        }

        user.round = lockedRound.length;
        user.bonus = 0;
        msg.sender.transfer(withdrawBonus.add(safety));
        emit logWithDraw(msg.sender, withdrawBonus.add(safety), now);
    }


    function investBonus(address targetAddr, uint wwin, bool totalFlag, uint addson)
    internal {
        if(targetAddr == ZERO_ADDR || allPlayers[targetAddr].invest == 0 || wwin == 0) return;
        Player storage target = allPlayers[targetAddr];
        target.bonus = target.bonus.add(wwin);
        if(addson != 0) target.sons = target.sons+1;
        if(totalFlag) target.totalBonus = target.totalBonus.add(wwin);
    }

    function getRandom(uint max)
    internal returns(uint) {
        _rand = _rand.add(1);
        uint rand = _rand*_rand;
        uint random = uint(keccak256(abi.encodePacked(block.difficulty, now, msg.sender, rand)));
        return random % max;
    }

    function start(uint time) external onlyAdmin() {
        require(time > now, "Invalid Time");
        _startTime = time;
    }

    function startArgs(uint dailyInvest, uint safePool, uint gloryPool, uint staticPool, uint[] memory locks) public onlyAdmin() {
        require(!isStart(), "Game Not Start Limit");
        _dailyInvest = dailyInvest;
        _safePool = safePool;
        _gloryPool = gloryPool;
        _staticPool = staticPool;
        for(uint i=0; i<locks.length; i++) {
            lockedRound.push(locks[i]);
        }
    }


    function isStart() public view returns(bool) {
        return _startTime != 0 && now > _startTime;
    }

    function userInfo(address payable target)
    public view returns (address, address, address, uint, uint, uint, uint, uint){
        Player memory self = allPlayers[target];
        Player memory parent = allPlayers[self.parent];
        Player memory grand = allPlayers[parent.parent];
        Player memory great = allPlayers[grand.parent];
        return (parent.self, grand.self, great.self,
        self.bonus, self.totalBonus, self.invest, self.sons, self.round);
    }

}