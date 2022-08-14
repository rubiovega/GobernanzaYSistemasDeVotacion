// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./ERC20/ERC20.sol";
import "./ERC20/ERC20Token.sol";
import "hardhat/console.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;    
}

contract Proposal is IExecutableProposal {
    string _title;   // Titulo de la propuesta
    string _description; // Descripción de la propuesta
    uint _budget;    // Presupuesto para llevar a cabo la propuesta
    address _creator;   // Dirección del participante que añade la propuesta
    uint _idProposal;   // Identificador de la propuesta en QuadraticVoting
    bool _approved; // Booleano para ver si la propuesta ya ha sido aprobada o no
    uint[] _idParticipants; // Array que contiene los identificadores de los participantes en QuadraticVoting que 
                            // han depositado algún voto en esta propuesta
    mapping (uint => uint) _participantIndex; // Mapping que contiene la posición en la que se encuentra el participante en el 
                                              // array _idParticipants                            
    mapping (uint => uint) _participantTokensInProposal; // Mapping que almacena como clave el id del participante en QuadraticVoting y 
                                                        // valor el numero de tokens depositados para la propuesta                                            
    

    constructor(string memory title, string memory description, uint budget, address c, uint idProp) {
        _title = title;
        _description = description;
        _budget = budget;
        _creator = c;
        _idProposal = idProp;      
        _approved = false;
    }

    function getTitle() external view returns(string memory) {
        return _title;
    }

    function getDescription() external view returns(string memory) {
        return _description;
    }

    function getBudget() external view returns(uint) {
        return _budget;
    }

    function getCreator() external view returns(address) {
        return _creator;
    }

    function isApproved() external view returns(bool) {
        return _approved;
    }
        
    function isSignalingProposal() external view returns (bool) {
        return _budget == 0;
    }

    function getIdParticipants() external view returns(uint[] memory) {
        return _idParticipants;
    }

    function getParticipantTokens(uint idParticipant) external view returns (uint) {
        return _participantTokensInProposal[idParticipant];
    }

    function getIdProposal() external view returns (uint) {
        return _idProposal;
    }

    function addParticipantVotes(uint indP, uint tokens) external {
        // Si el participante no ha depositado ningun voto a esta propuesta,
        // añadimos el participante al array _idParticipants
        if(_participantTokensInProposal[indP] == 0) { 
            _idParticipants.push(indP);
            _participantIndex[indP] = _idParticipants.length - 1;
        }

        _participantTokensInProposal[indP] += tokens;
    }

    function withdrawParticipantVotes(uint indP, uint tokens) external {
        _participantTokensInProposal[indP] -= tokens;

        // Si no tiene votos depositados en la propuesta, eliminar el participante del array _idParticipants 
        if(_participantTokensInProposal[indP] == 0) {

        }        
    }

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override {
        //TODO
    }

}

contract QuadraticVoting {
    address public _owner;  // Propietario del contrato
    uint public _tokenPrice;   // Precio del token
    uint public _maxTokens;    // Número máximo de tokens que se ponen a la venta para las votaciones
    ERC20Token _ERC20Token;  // Contrato ERC20Token
    uint public _totalBudget;  // Presupuesto para financiar propuestas
    string public _name;   // Nombre del token
    string public _symbol; // Simbolo para representar el token
    bool public _votingOpen;   // Booleano para ver si el periodo de votación está abierto 
    bool public _votingClosed;  // Booleano para ver si el periodo de votación está cerrado    
    
    uint _idParticipant;    // Identificador del último participante registrado
    mapping (address => uint) _idParticipants;  // Mapping que almacena como clave la dirección y valor el identificador de cada participante
    mapping (uint => uint) _participantTokens;  // Mapping que almacena como clave el identificador del participante y como valor los tokens que tiene
    
    uint _idProposal;   // Identificador de la última propuesta creada
    Proposal[] _proposals;  // Array de las propuestas creadas
    mapping (uint => uint) _proposalIndex;  // Mapping que almacena como clave el identificador de cada propuesta y como valor la posición en la
                                            // que se encuentra la propuesta en el array _proposals
    
    uint[] _pendingProposals;   // Array que contiene los identificadores de las propuestas pendientes por aprobar
    uint[] _approvedProposals;  // Array que contiene los identificadores de las propuestas aprobadas
    uint[] _signalingProposals; // Array que contiene los identificadores de las propuestas signaling

    mapping (uint => uint) _indexPendingProposal;   // Mapping que almacena como clave el identificador de la propuesta y como valor el 
                                                    // indice de la propuesta en el array _pendingProposals
    mapping (uint => uint) _indexSignalingProposal; // Mapping que almacena como clave el identificador de la propuesta y como valor el 
                                                    // indice de la propuesta en el array
    
    uint public _remainingWei; // Variable para almacenar la propina del owner


    constructor(uint numTokens, uint tokenPrice) {
        _owner = msg.sender; 
        _tokenPrice = tokenPrice;       
        _maxTokens = numTokens;
        _name = "Token";
        _symbol = "TBC";
        _totalBudget = 0;
        _votingOpen = false;
        _votingClosed = false;
        _idParticipant = 0;
        _idProposal = 0;        
        _remainingWei = 0;
        _ERC20Token = new ERC20Token(_maxTokens, _name, _symbol);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not the owner of the contract!");
        _;
    }

    modifier votingIsOpen() {
        require(_votingOpen, "The voting is not opened!");
        _;
    }

    modifier votingIsFinished() {
        require(_votingClosed, "The voting has not finished!");
        _;
    }

    // Modifier que comprueba si un participante esta registrado 
    modifier partipicantExists() {
        require(_idParticipants[msg.sender] != 0, "The participant is not registered!");                
        _;
    }

    // Modifier que comprueba si la cantidad de Wei del msg.value permite comprar los tokens deseados
    modifier enoughWeiAmount(uint tokensToBuy) {
        require(msg.value >= _tokenPrice*tokensToBuy, "Not enough Wei!");
        _;
    }

    // Modifier que comprueba si la cantidad de Wei del msg.value permite comprar al menos un token
    modifier enoughWeiToBuyAToken() {
        require(msg.value >= _tokenPrice, "Not enough Wei!");
        _;
    }

    function openVoting() external payable onlyOwner {
        require(msg.value > 0, "Budget should not be zero!");
        _totalBudget = msg.value;
        if(!_votingOpen) _votingOpen = true;    
    }

    function addParticipant() external payable enoughWeiToBuyAToken {
        require(_idParticipants[msg.sender] == 0, "Participant already exists!"); 
        
        uint amount = msg.value / _tokenPrice;  // Tokens que puede comprar el participante
        _remainingWei += msg.value % _tokenPrice; // La cantidad de Wei sobrante se la queda el owner del contrato como propina
        
        ERC20Token erc20 = ERC20Token(getERC20());
        erc20.mint(msg.sender, amount);
        // (bool success,) = address(address(erc20)).delegatecall(abi.encodeWithSignature("mint(address, uint)", msg.sender, amount));
        // require(success, "delegatecall failed!");
        
        _idParticipant++;
        _idParticipants[msg.sender] = _idParticipant;
        _participantTokens[_idParticipant] = amount;        
    }

    function addProposal(string memory title, string memory description, uint budget, address c) external votingIsOpen returns (uint) {        
        // No se si hay que comprobar si la propuesta ya existe. Es que eso creo que gastara mazo gas
        // porque hay que recorrer todas las propuestas e ir comparando si tiene el mismo titulo, descripción, etc...
        
        _idProposal++;
        Proposal proposal = new Proposal(title, description, budget, c, _idProposal);
        _proposals.push(proposal);
        _proposalIndex[_idProposal] = _proposals.length - 1;

        // Añadir propuesta al array de _pendingProposals
        _pendingProposals.push(_idProposal);
        _indexPendingProposal[_idProposal] = _pendingProposals.length - 1;

        // Si es una propuesta signaling añadir al array de _signalingProposals
        if(budget == 0) {
            _signalingProposals.push(_idProposal);
            _indexSignalingProposal[_idProposal] = _signalingProposals.length - 1;
        }

        return _idProposal;
    }

    function cancelProposal(uint idProp) external votingIsOpen {
        uint ind = _proposalIndex[idProp];
        Proposal p = _proposals[ind];

        require(msg.sender == p.getCreator(), "Not the creator of the proposal!");
        require(!p.isApproved(), "Can't cancel a approved proposal!");

        uint[] memory idParticipants = p.getIdParticipants();   // Array de los identificadores de los participantes  
                                                                // que tienen votos en la propuesta
        
        // Devolvemos los tokens a todos los participantes de la propuesta
        for(uint i = 0; i < idParticipants.length; i++) {
            uint id = idParticipants[i];
            _participantTokens[id] += p.getParticipantTokens(id);
        }

        console.log("Length proposals before cancel: ", _proposals.length);

        // Borramos la propuesta del array _proposals
        for(uint i = ind; i < _proposals.length; i++) {
            uint idP = _proposals[i+1].getIdProposal();
            _proposalIndex[idP] = i;
            _proposals[i] = _proposals[i+1];
        }

        _proposals.pop();

        console.log("Length proposals after cancel: ", _proposals.length);

/*
        uint indPend = _pendingProposals[idProp];
        
        // Borramos la propuesta del array _pendingProposals
        for(uint i = indPend; i < _pendingProposals.length; i++) {
            uint idP2 = _pendingProposals[i+1];
            _indexPendingProposal[idP2] = i;        
            _pendingProposals[i] = _pendingProposals[i+1];
        }
        _pendingProposals.pop();


        if(p.isSignalingProposal()) {
            uint indSign = _signalingProposals[idProp];

            for(uint i = indSign; i < _signalingProposals.length; i++) {
                uint idP2 = _signalingProposals[i+1];
                _indexSignalingProposal[idP2] = i;        
                _pendingProposals[i] = _pendingProposals[i+1];
            }
            _signalingProposals.pop();
        }

*/
        // Borrar la propuesta 
        delete p;

        // Borrar propuesta del mapping _proposalIndex
        delete _proposalIndex[idProp];

        // No se si se puede hacer un destroy del Proposal, creo recordar que un contrato existe
        // para siempre en la blockchain, pero en los apuntes he visto la siguiente funcion 
        // selfdestruct(address payable recipient) nose si esto gasta mucho gas                    
    }
    
    function buyTokens(uint tokensToBuy) public payable partipicantExists enoughWeiAmount(tokensToBuy) {
        ERC20Token erc20 = ERC20Token(getERC20());
        erc20.mint(msg.sender, tokensToBuy);
        // (bool success,) = address(erc20).delegatecall(abi.encodeWithSignature("mint(address, uint)", msg.sender, tokensToBuy));
        // require(success, "delegatecall failed!");        

        uint idP = _idParticipants[msg.sender];        
        _participantTokens[idP] += tokensToBuy;
        _remainingWei += msg.value - (_tokenPrice * tokensToBuy);
    }

    function sellTokens(uint tokensToSell) external partipicantExists {
        uint idP = _idParticipants[msg.sender];        
        
        require(_participantTokens[idP] >= tokensToSell, "Participant does not have enough token to sell!");
        
        _participantTokens[idP] -= tokensToSell;        
        (bool sent, ) = msg.sender.call{value: tokensToSell * _tokenPrice}("");
        
        require(sent, "Failed to sell Tokens");

        ERC20Token erc20 = ERC20Token(getERC20());
        erc20.burn(tokensToSell);
        // (bool success,) = address(erc20).delegatecall(abi.encodeWithSignature("burn(uint)", tokensToSell));
        // require(success, "delegatecall failed!");  
    }

    function getERC20() public view returns (address) {
       return address(_ERC20Token);
    }

    function getPendingProposals() external view votingIsOpen returns (uint[] memory) {
        return _pendingProposals;
    }

    function getApprovedProposals() external view votingIsOpen returns (uint[] memory) {        
        return _approvedProposals;
    }


    function getSignalingProposals() external view votingIsOpen returns (uint[] memory) {        
        return _signalingProposals;
    }

    function getProposalInfo(uint idProp) external view votingIsOpen returns(string memory, string memory, uint) {   
        return (_proposals[idProp].getTitle(), _proposals[idProp].getDescription(), _proposals[idProp].getBudget());
    }

    function stake(uint idProp, uint numVotes) external partipicantExists {    
        uint idParticipant = _idParticipants[msg.sender];
        uint tokensInProposal = _proposals[idProp].getParticipantTokens(idParticipant);                
        uint t = (tokensInProposal + 1) / 2;
        uint nV = tokensInProposal;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (tokensInProposal / t + t) / 2;
        }

        //Calcular los tokens necesarios para depositar los votos que se van a depositar
        nV += numVotes;        
        uint tokensNeeded = (nV * nV) - tokensInProposal;

        // Comprobar que el participante posee los suficientes tokens para comprar los votos
        require(_participantTokens[idParticipant] >= tokensNeeded, "Not enough tokens to vote the proposal!");

        // Comprobar que el participante ha cedido (con approve) el uso de esos tokens a la cuenta del contrato de la votacion
        


        // Depositar los tokens del participante a la propuesta
        _participantTokens[idParticipant] -= tokensNeeded;
        _proposals[idProp].addParticipantVotes(idProp, tokensNeeded);
    }

    function withdrawFromProposal (uint numVotes, uint idProposal) external partipicantExists {
        uint indP = _proposalIndex[idProposal];        
        require(!_proposals[indP].isApproved(), "Proposal approved!");
        
        uint idParticipant = _idParticipants[msg.sender];
        uint numTokensInProposal = _proposals[indP].getParticipantTokens(indexParticipant);

        // Comprobar que el participante ha depositado votos en la propuesta
        require(numTokensInProposal != 0, "Participant does not have votes in the proposal!");

        uint t = (numTokensInProposal + 1) / 2;
        uint nV = numTokensInProposal;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (numTokensInProposal / t + t) / 2;
        }

        // Devolver al participante los tokens que utilizó para depositar los votos que ahora retira
        uint tokensToWithdraw = numTokensInProposal - (numVotes * numVotes);
        _proposals[indP].withdrawParticipantVotes(idParticipant, tokensToWithdraw);
        _participantTokens[idParticipant] += tokensToWithdraw;
    }

    // function _checkAndExecuteProposal() internal {
    //     IExecutableProposal(payable(address del proposal)).executeProposal{value: 0, gas: 0}();
    // }

    function closeVoting() external onlyOwner {
        //Realizar las tareas descritas en el enunciado
        //...

        // Inicializar las variables de estado para permitir abrir un nuevo proceso de votacion        
        _totalBudget = 0;
        _votingOpen = false;
        _votingClosed = false;
        _idParticipant = 0;
        _idProposal = 0;        
        _remainingWei = 0;
    }
}