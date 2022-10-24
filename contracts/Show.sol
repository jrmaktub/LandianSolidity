//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./Ticket.sol";

import "./Utils.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Show {
    address public owner; // dueño del evento/show.

    Ticket ticketContract;

    uint256 public showId; // id del show
    // string public title; //  titulo del show
    // string public description; // The description del show
    // string public image; // imagen del show
    // string public date; // ISO 8601 formato
    // string public openingTime; // ISO 8601 formato
    // string public closingTime; // ISO 8601 formato
    // Status public status; // Status del show

    address payable[] public socios;
    address payable public gananciasContrato;
    address payable[] public inversionistas;

    uint256 percentageSocios = 30;
    uint256 percentageContrato = 40;
    uint256 percentageInversionistas = 30;

    SeatType[] public seatTypes; // listado de asientos, seatTypeId es el index del array
    mapping(uint256 => Seat[]) public seats; // mapping de seatTypeId a seats array para cada seat type

    uint256 public MAX_SEAT_TYPES = 250; // numero maximo de typos de asientos permitidos 
    uint256 public MAX_SEATS = 1000; // numero maximo de asientos por typo de asientos

    enum Status {
        Pendding,
        Scheduled,
        Ended,
        Cancelled
    }

    struct SeatType {
        uint256 id; // el id del seat type, este es el index del seatTypes array
        string name; // nombre del seat type. e.g. "Standard", "VIP", "Premium"
        uint256 price; // precio del seat type in wei
        bool available; // verdadero si el asiento esta disponible
    }

    struct Seat {
        uint256 id; //numero en el seat type. Este es el index en el seats array. Se puede identificar el seat por el seatTypeId y seatId.
        string name; // Nombre del seat. e.g. "Standard 1", "VIP 1", "Premium 1"
        uint256 ticketId; // ticketId del seat. Publicado por el  OpenZeppelin Counter en el  Ticket contract (ERC721)
        bool available; // verdadero si puede ser reservado
    }

    event PayeeAdded(address account);

    event ShowScheduled(uint256 indexed showId, string title, string date); // emitted cuando el show empieza

    error Unauthorized(); // error cuando el caller no es el owner. 
    error ShowIsNotScheduled(); //show no esta en el status scheduled 

    constructor(
        address _owner,
        uint256 _showId,
        // string memory _title,
        // string memory _description,
        // string memory _image,
        // string memory _date,
        // string memory _openingTime,
        // string memory _closingTime,
        address payable[] memory _socios,
        address payable[] memory _inversionistas,
        // address[] memory _gananciasContrato,
        // address[] memory _inversionistas,
        uint256 _percentageSocios,
        uint256 _percentageContrato,
        uint256 _percentageInversionistas
    ) {
        owner = _owner;

        showId = _showId;
        // title = _title;
        // description = _description;
        // image = _image;
        // date = _date;
        // openingTime = _openingTime;
        // closingTime = _closingTime;

        // status = Status.Pendding;

        ticketContract = new Ticket(this);
        //
        socios = _socios;
        gananciasContrato = payable(msg.sender);
        inversionistas = _inversionistas;
        percentageSocios = _percentageSocios;
        percentageContrato = _percentageContrato;
        percentageInversionistas = _percentageInversionistas;
    }

    //soltanndo pagos a cada parte correspondiente
    event PaymentReleased(address to, uint256 amount);

    event ERC20PaymentReleased(
        IERC20 indexed token,
        address to,
        uint256 amount
    );
    uint256 private _totalReleased;
    mapping(address => uint256) private _released;
    mapping(IERC20 => uint256) private _erc20TotalReleased;
    mapping(IERC20 => mapping(address => uint256)) private _erc20Released;

      //comprando ticket
  
    function buyTicket(
        uint256 _seatTypeId,
        uint256 _seatNum,
        string memory _buyerName
    )
        public
        payable
        validDestinationAddress(msg.sender)
        returns (uint256)
    {
        seats[_seatTypeId][_seatNum].available = false;

        uint256 tiekctId = ticketContract.createTicket(
            _seatTypeId,
            _seatNum,
            seats[_seatTypeId][_seatNum].name,
            seatTypes[_seatTypeId].price,
            _buyerName,
            msg.sender
        );

        // seats[_seatNum].ticketId = tiekctId;

       

        return tiekctId;
    }

    //conseguir info del ticket
    function getTicketInfo(uint256 _ticketId)
        public
        view
        returns (Ticket.TicketInfo memory)
    {
        return ticketContract.getTicketInfo(_ticketId);
    }

    function existTicket(uint256 _ticketId) public view returns (bool) {
        return ticketContract.existTicket(_ticketId);
    }

    // function offerTicket(uint256 _ticketId) public onlyScheduledShow {
    //     ticketContract.offerTicket(msg.sender, _ticketId);
    // }

    //conseguir tickets para trade
    function getTradableTickets()
        public
        view
        returns (Ticket.TicketInfo[] memory)
    {
        uint256[] memory tradableTicketIds = ticketContract
            .getTradableTickets();
        Ticket.TicketInfo[] memory tradableTickets = new Ticket.TicketInfo[](
            tradableTicketIds.length
        );
        for (uint256 i = 0; i < tradableTicketIds.length; i++) {
            tradableTickets[i] = ticketContract.getTicketInfo(
                tradableTicketIds[i]
            );
        }
        return tradableTickets;
    }
    //comprando ticket en reventa
    function buyOfferedTicket(uint256 _ticketId, string memory _buyerName)
        public
        payable
        
        validDestinationAddress(msg.sender)
        paidEnough(ticketContract.getTicketPrice(_ticketId))
        returns (uint256)
    {
        Ticket.TicketInfo memory ticketInfo = ticketContract.getTicketInfo(
            _ticketId
        );

        uint256 tiekctId = ticketContract.buyOfferedTicket(
            _ticketId,
            msg.sender,
            //requerimiento 4
            _buyerName
        );

        // seats[ticketInfo.seatTypeId][ticketInfo.seatNum].ticketId = tiekctId;
        //regresar diniero extra

        if (msg.value > ticketInfo.price) {
            uint256 returnValue = msg.value - ticketInfo.price;
            (bool sent, ) = payable(msg.sender).call{value: returnValue}("");
            require(sent, "Failed to send Ether");
        }

        return tiekctId; // returned ticket id is the same as the one of the offered ticket
    }

    //chequiando si la persona tiene ticket correcto
    function checkIn(uint256 _ticketId) public  {
        ticketContract.checkIn(_ticketId);
    }

    //balance del contrato. Requerimiento #2
    function getContractBalance() public view returns(uint){
        //uint balanceContract = address(this).balance * 10**18;
        uint ContractBalance = address(this).balance * 10**18;
        return ContractBalance;
        // return ContractAddress.balance;
    }

    //pagandole a cada persona su parte correspondiente
    //requerimiento 7
    //siguiendo los pasos de https://github.com/benber86/nft_royalties_market/blob/main/contracts/RoyaltiesPayment.sol
    function release(address payable) public {
        uint256 balanceContract = address(this).balance * 10**18;
        uint256 shareSocios = ((balanceContract * percentageSocios) / 100);
        uint256 shareContract = ((balanceContract * percentageContrato) / 100);
        uint256 shareInversionistas = ((balanceContract *
            percentageInversionistas) / 100);

        //ticketHolder.transfer(msg.value);

        for (uint256 i = 0; i < socios.length; i++) {
            socios[i].transfer(shareSocios);
        }

        for (uint256 i = 0; i < inversionistas.length; i++) {
            inversionistas[i].transfer(shareInversionistas);
        }

        // payable(address(msg.sender).send(shareContract),
        //feeAccount.transfer(_totalPrice - item.price);

        //pagarle al contrato su parte correspondiente
        gananciasContrato.transfer(shareContract);
    }

    //address payable[] memory _inversionistas,
    //uint256 _percentageInversionistas
    //Requerimiento 5 Agregar inversores
    function _addPayee(address account)
        private
    {
        require(
            account != address(0),
            " cuenta no es address 0"
        );

        // for (uint256 i = 0; i < inversionistas.length; i++){
        //     inversionistas[i].push(account);
        // }
        // inversionistas.push(account);
        inversionistas.push(payable(account));

        // _payees.push(account);
        // _shares[account] = shares_;
        // _totalShares = _totalShares + shares_;
        // emit PayeeAdded(account, shares_);
         emit PayeeAdded(account);
    }

    //Requerimiento 6 Agregar inversores
    function _removePayee(address account) public{
        // require( account != address(0), "cuenta no es address 0");
        // // mapping (address => uint256) memory inversionistasIndexes;

        // if (index >= inversionistas.length) return;

        // for (uint i = index; i<inversionistas.length-1; i++){
        //     inversionistas[i] = inversionistas[i+1];
        // }
        // inversionistas.pop();
        // uint id = inversionistasIndexes[account];
        // delete inversionistas[id];
    }



    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    // modifier onlyScheduledShow() {
    //     if (status != Status.Scheduled) {
    //         revert ShowIsNotScheduled();
    //     }
    //     _;
    // }

    modifier onlyExistingSeatType(uint256 _seatTypeId) {
        require(_seatTypeId < seatTypes.length, "Seat type does not exist");
        _;
    }

    modifier onlyAvailableSeatType(uint256 _seatTypeId) {
        require(_seatTypeId < seatTypes.length, "Seat type does not exist");
        require(seatTypes[_seatTypeId].available, "Seat type is not available");
        require(seatTypes[_seatTypeId].price > 0, "Seat price is zero");
        _;
    }

    modifier onlyExistingSeat(uint256 _seatTypeId, uint256 _seatNum) {
        require(_seatTypeId < seatTypes.length, "Seat type does not exist");
        require(_seatNum < seats[_seatTypeId].length, "Seat does not exist");
        _;
    }

    modifier onlyAvailableSeat(uint256 _seatTypeId, uint256 _seatNum) {
        require(_seatTypeId < seatTypes.length, "Seat type does not exist");
        require(_seatNum < seats[_seatTypeId].length, "Seat does not exist");
        require(
            seats[_seatTypeId][_seatNum].available,
            "Seat is not available"
        );
        _;
    }

    modifier validSeatTypePrice(uint256 _price) {
        require(_price > 0, "Seat price is zero");
        _;
    }

    modifier validSeatTypeName(string memory _name) {
        require(
            Utils.strlen(_name) > 0 && Utils.strlen(_name) <= 64,
            "Seat type name is not valid"
        );
        _;
    }

    modifier uniqueSeatTypeName(string memory _name) {
        for (uint256 i = 0; i < seatTypes.length; i++) {
            if (Utils.strcmp(seatTypes[i].name, _name)) {
                revert("Seat type name already used");
            }
        }
        _;
    }

    modifier enoughSpaceForNewSeatTypes(uint256 _numSeatTypes) {
        require(
            seatTypes.length + _numSeatTypes <= MAX_SEAT_TYPES,
            "No hay espacio para nuevos asientos"
        );
        _;
    }

    modifier validSeatName(string memory _name) {
        require(
            Utils.strlen(_name) > 0 && Utils.strlen(_name) <= 64,
            "Seat name cannot be longer than 32 characters"
        );
        _;
    }

    modifier uniqueSeatName(string memory _name) {
        for (uint256 i = 0; i < seatTypes.length; i++) {
            for (uint256 j = 0; j < seats[i].length; j++) {
                // the key seatTypeId is the index of seatTypes array
                if (Utils.strcmp(seats[i][j].name, _name)) {
                    revert("Seat name already used");
                }
            }
        }
        _;
    }

   

    
    //transfiriendo la propiedad de owner
    function transferOwnershipTo(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // function setShowScheduled() public onlyOwner {
    //     require(status == Status.Pendding, "Show is not pending");
    //     status = Status.Scheduled;
    //     // emit ShowScheduled(showId, title, date);
    //     //  emit ShowScheduled(showId, title);
    // }

    // function updateTitle(string memory _title) public onlyOwner {
    //     title = _title;
    // }

    // function updateDescription(string memory _description) public onlyOwner {
    //     // description = _description;
    //     description = _description;
    // }

    // function updateImage(string memory _image) public onlyOwner {
    //     image = _image;
    // }

    // function updateDate(string memory _date) public onlyOwner {
    //     date = _date;
    // }

    // function updateOpeningTime(string memory _openingTime) public onlyOwner {
    //     openingTime = _openingTime;
    // }

    // function updateClosingTime(string memory _closingTime) public onlyOwner {
    //     closingTime = _closingTime;
    // }

    function setMaxSeatTypes(uint256 _maxSeatTypes) public onlyOwner {
        MAX_SEAT_TYPES = _maxSeatTypes;
    }

    function setMaxSeats(uint256 _maxSeats) public onlyOwner {
        MAX_SEATS = _maxSeats;
    }

    

    function getSeatTypes()
        public
        view
        returns (
            uint256[] memory,
            string[] memory,
            uint256[] memory,
            bool[] memory
        )
    {
        uint256[] memory seatTypeIds = new uint256[](seatTypes.length);
        string[] memory names = new string[](seatTypes.length);
        uint256[] memory prices = new uint256[](seatTypes.length);
        bool[] memory availables = new bool[](seatTypes.length);

        for (uint256 i = 0; i < seatTypes.length; i++) {
            seatTypeIds[i] = seatTypes[i].id;
            names[i] = seatTypes[i].name;
            prices[i] = seatTypes[i].price;
            availables[i] = seatTypes[i].available;
        }

        return (seatTypeIds, names, prices, availables);
    }

    function getSeatType(uint256 _seatTypeId)
        public
        view
        onlyExistingSeatType(_seatTypeId)
        returns (SeatType memory)
    {
        return seatTypes[_seatTypeId];
    }

    function getRawSeatTypes() public view returns (SeatType[] memory) {
        return seatTypes;
    }

    function getSeatTypesCount() public view returns (uint256) {
        return seatTypes.length;
    }

    function getSeatTypePrice(uint256 _seatTypeId)
        public
        view
        onlyExistingSeatType(_seatTypeId)
        returns (uint256)
    {
        return seatTypes[_seatTypeId].price;
    }

    function updateSeatTypeName(uint256 _seatTypeId, string memory _name)
        public
        onlyOwner
        onlyExistingSeatType(_seatTypeId)
        validSeatTypeName(_name)
        uniqueSeatTypeName(_name)
    {
        seatTypes[_seatTypeId].name = _name;
    }

    function updateSeatTypePrice(uint256 _seatTypeId, uint256 _price)
        public
        onlyOwner
        onlyExistingSeatType(_seatTypeId)
        validSeatTypePrice(_price)
    {
        seatTypes[_seatTypeId].price = _price;
    }

    function updateSeatTypeAvailability(uint256 _seatTypeId, bool _available)
        public
        onlyOwner
        onlyExistingSeatType(_seatTypeId)
    {
        seatTypes[_seatTypeId].available = _available;
    }

    function addSeat(uint256 _seatTypeId, string memory _name)
        public
        onlyOwner
 
        returns (uint256)
    {
        uint256 seatNum = seats[_seatTypeId].length;
        Seat memory seat = Seat(seatNum, _name, 0, true);
        seats[_seatTypeId].push(seat);

        return seatNum;
    }

    function addSeats(uint256 _seatTypeId, string[] calldata _names)
        public
        onlyOwner
        returns (uint256[] memory)
    {
        require(_names.length > 0, "No seats to add");

        uint256[] memory seatNums = new uint256[](_names.length);
        for (uint256 i = 0; i < _names.length; i++) {
            seatNums[i] = addSeat(_seatTypeId, _names[i]);
        }

        return seatNums;
    }

    function getSeat(uint256 _seatTypeId, uint256 _seatNum)
        public
        view
        onlyExistingSeat(_seatTypeId, _seatNum)
        returns (Seat memory)
    {
        return seats[_seatTypeId][_seatNum];
    }

    function getSeats(uint256 _seatTypeId)
        public
        view
        returns (
            uint256[] memory,
            string[] memory,
            uint256[] memory,
            bool[] memory
        )
    {
        uint256[] memory seatNums = new uint256[](seats[_seatTypeId].length);
        string[] memory names = new string[](seats[_seatTypeId].length);
        uint256[] memory ticketIds = new uint256[](seats[_seatTypeId].length);
        bool[] memory availables = new bool[](seats[_seatTypeId].length);

        for (uint256 i = 0; i < seats[_seatTypeId].length; i++) {
            seatNums[i] = seats[_seatTypeId][i].id;
            names[i] = seats[_seatTypeId][i].name;
            ticketIds[i] = seats[_seatTypeId][i].ticketId;
            availables[i] = seats[_seatTypeId][i].available;
        }

        return (seatNums, names, ticketIds, availables);
    }

    function getRawSeats(uint256 _seatTypeId)
        public
        view
        returns (Seat[] memory)
    {
        return seats[_seatTypeId];
    }

    function getSeatsCount(uint256 _seatTypeId)
        public
        view

        returns (uint256)
    {
        return seats[_seatTypeId].length;
    }

    function getSeatName(uint256 _seatTypeId, uint256 _seatNum)
        public
        view
        onlyExistingSeat(_seatTypeId, _seatNum)
        returns (string memory)
    {
        return seats[_seatTypeId][_seatNum].name;
    }

    function updateSeatName(
        uint256 _seatTypeId,
        uint256 _seatNum,
        string memory _name
    )
        public
        onlyOwner
        onlyExistingSeat(_seatTypeId, _seatNum)
        validSeatName(_name)
        uniqueSeatName(_name)
    {
        seats[_seatTypeId][_seatNum].name = _name;
    }

    function updateSeatAvailability(
        uint256 _seatTypeId,
        uint256 _seatNum,
        bool _available
    )
        public
        onlyOwner
        onlyExistingSeat(_seatTypeId,_seatNum)
    {
        seats[_seatTypeId][_seatNum].available = _available;
    }



    modifier validDestinationAddress(address _destination) {
        require(_destination != address(0), "Invalid destination address");
        require(_destination != address(this), "Invalid destination address");
        _;
    }

    modifier paidEnough(uint256 _price) {
        require(msg.value >= _price, "No hay suficiente BNB");
        _;
    }

    modifier paidEnoughForOffer(uint256 _ticketId) {
        require(
            msg.value >= ticketContract.getTicketPrice(_ticketId),
            "No hay suficiente BNB"
        );
        _;
    }

    function isSeatAvailable(uint256 _seatTypeId, uint256 _seatNum)
        public
        view
        onlyExistingSeat(_seatTypeId,_seatNum)
        returns (bool)
    {
        return seats[_seatTypeId][_seatNum].available;
    }
 
}
