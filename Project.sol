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
    string _description;    // Descripcion de la propuesta
    uint _budget;           // Presupuesto de la propuesta
    address _creator;       // Creador de la propuesta
    bool _approved;         //  Booleano que indica si la propuesta ha sido o no aprobadas
    uint _numTokens;  // Numero de tokens reacaudados por el proposal 
    address[] _addressParticipants; // Array que contiene los address de los participantes que votan la propuesta
    // mapping (address => bool) _participantExists; // Mapping que verifica si existe o no un participante en la propuesta
    mapping (address => uint) _participantsProp; // Mapping cuya clave es el address y el valor es sus tokens

    constructor(string memory title, string memory description, uint budget) {
        _title = title;
        _description = description;
        _budget = budget;
        _creator = msg.sender;         
        _approved = false;
        _numTokens = 0;
    }

    function isApproved() external view returns (bool) {
        return _approved;
    }

    function isSignalingProposal() external view returns (bool) {
        return _budget == 0;
    }

    function getParticipants() external view returns (address[] memory) {
        return _addressParticipants;
    }

    function getParticipantTokens(address a) external view returns (uint) {
        return _participantsProp[a];
    }

    function getTitle() external view returns (string memory) {
        return _title;
    }

    function getDescription() external view returns (string memory) {
        return _description;
    }

    function getBudget() external view returns (uint) {
        return _budget;
    }

    function getCreator() external view returns (address) {
        return _creator;
    }

    function getNumTokens() external view returns (uint) {
        return _numTokens;
    }

    function addParticipantVotes(uint tokens) external {
        if(_participantsProp[msg.sender] == 0) {
            _addressParticipants.push(msg.sender);
            // _participantExists[msg.sender] = true;
        }

        _participantsProp[msg.sender] += tokens;
        _numTokens += tokens;
    }

    function participantHasVotes() external view returns(bool) {
        return _participantsProp[msg.sender] != 0;
    }

    function withdrawParticipantVotes(uint tokensToWithdraw) external {
        _participantsProp[msg.sender] -= tokensToWithdraw;
        
        // Si el participante no tiene tokens, se borra de la propuesta
        if(_participantsProp[msg.sender] == 0) {            
            // _participantExists[msg.sender] = false;

            uint pos = 0;

            while(_addressParticipants[pos] != msg.sender)
                pos++;

            for(uint i = pos; i < _addressParticipants.length; i++)
                _addressParticipants[i] = _addressParticipants[i+1];

            _addressParticipants.pop();
        }
    }

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override{
        //TODO
    }

}

contract QuadraticVoting {
    address _owner;  // Contract owner.
    
    uint _maxTokens;    // Numero de tokens total
    uint _tokenPrice;   // Precio del token
    string _name;       // Nombre del token
    string _symbol;     // Simpobolo del token
    ERC20Token _ERC20Token;  // ERC20Token contract
    bool public _votingOpen; // Booleano que indica si la votación esta abierta
    bool _votingClosed; // Booleano que indica si la votación esta cerrada
    uint _totalBudget;  // Presupuesto del que se dispone para financiar propuestas
    uint _numParticipants;
    
    uint _idProposal;   // Identificador de la ultima propuesta registrada
    mapping (uint => Proposal) _proposals;  // Mapping que contiene como clave el identificadore de la 
                                            // propuesta y como valor el contrato de cada Proposal
    uint[] _pendingProposals;   // Array con los identificadores de las propuestas pendientes
    uint[] _approvedProposals;   // Array con los identificadores de las propuestas aprovadas
    uint[] _signalingProposals;   // Array con los identificadores de las propuestas signaling
    
    mapping (address => bool) private _participants; // Mapping de participantes que almacenan la direccion y 
                                                     // un booleano para indicar si esta registrado o no 
    
    uint public _remainingWei; // Variable para almacenar la propina del owner

 
    constructor(uint numTokens, uint tokenPrice) {
        _owner = msg.sender;        
        _maxTokens = numTokens;
        _tokenPrice = tokenPrice;
        _name = "Token";
        _symbol = "TBC";
        _totalBudget = 0;
        _idProposal = 0;
        _numParticipants=0;
         _remainingWei = 0;
        _votingOpen = false;
        _votingClosed = false;
        _ERC20Token = new ERC20Token(_maxTokens,_name, _symbol);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "ERROR: Not the owner of the contract!");
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

    // Modifier que comprueba si un participante est  inscrito 
    modifier partipicantExists() {
        //supongo que hay una mejor forma de comprobar que esta dado de alta
        require (_participants[msg.sender], "The participant is not registered!");                
        _;
    }

    // Modifier que comprueba si la cantidad de Wei del msg.value permite comprar
    // los tokens deseados
    modifier enoughWeiAmount(uint tokensToBuy) {
        require(msg.value >= _tokenPrice*tokensToBuy, "Not enough Wei!");
        _;
    }

    // modifier que comprueba si la cantidad de Wei del msg.value permite comprar
    // al menos un token
    modifier enoughWeiToBuyAToken () {
        require(msg.value >= _tokenPrice, "Not enough Wei!");
        _;
    }

    function openVoting() external payable onlyOwner {
        _totalBudget = msg.value;
        if(!_votingOpen) _votingOpen = true;    
    }

    function addParticipant() external payable enoughWeiToBuyAToken {
        require(!_participants[msg.sender], "Participant already exists!"); // Comprobar mejor forma si existe o no el participante
        
        _participants[msg.sender] = true;
        
        uint amount = msg.value / _tokenPrice;
        _remainingWei += msg.value % _tokenPrice; // La cantidad de Wei sobrante se la 
                                                  // queda el owner como propina    
        _numParticipants++;
        _ERC20Token.mint(msg.sender, amount);    
    }

    function addProposal(address p) external votingIsOpen returns (uint) {
        _idProposal++;
        _pendingProposals.push(_idProposal);
        
        _proposals[_idProposal] = Proposal(p);
        
        if(_proposals[_idProposal].getBudget() == 0) {
            _signalingProposals.push(_idProposal);
        }
        return _idProposal;
    }

    function cancelProposal(uint idProp, address prop) external votingIsOpen {
        require (msg.sender == _proposals[idProp].getCreator(), "Not the proposal creator!");            
        require(!_proposals[idProp].isApproved(), "Can't cancel an approved proposal!");                
        uint pos = 0;
        
        // Recorremos el array de _pendingProposals para encontrar el indice en el que se encuentra el idProp
        while(_pendingProposals[pos] != idProp)
            pos++;

        // Eliminamos la propuesta idProp del array de _pendingProposals
        for(uint i = pos; i < _pendingProposals.length-1; i++) 
            _pendingProposals[i] = _pendingProposals[i+1];
        
        _pendingProposals.pop();

        // Si idProp es una propuesta signaling, la eliminamos del array de _signalingProposals
        if(_proposals[idProp].getBudget() == 0) {
            pos = 0;

            while(_signalingProposals[pos] != idProp)            
                pos++;

            for(uint i = pos; i < _signalingProposals.length-1; i++)
                _signalingProposals[i] = _signalingProposals[i+1];

            _signalingProposals.pop();
        }
                
        //devolver tokens a los participantes de la propuesta
        address[] memory addressParticipants = _proposals[idProp].getParticipants();

        for(uint i = 0; i < addressParticipants.length; i++) {
            uint participantTokensInProposal = _proposals[idProp].getParticipantTokens(addressParticipants[i]);
            _ERC20Token.transferFrom(prop, addressParticipants[i], participantTokensInProposal);           
        }

        // Borrar propuesta del mapping _proposals
        delete _proposals[idProp];                
    }
    
    function buyTokens(uint tokensToBuy) public payable partipicantExists enoughWeiAmount(tokensToBuy) { 
        _ERC20Token.mint(msg.sender, tokensToBuy);        
        _remainingWei += msg.value - (_tokenPrice*tokensToBuy);        
    }

    function sellTokens(uint tokensToSell) external partipicantExists {        
        require(_ERC20Token.balanceOf(msg.sender) >= tokensToSell, "Participant does not have enough tokens to sell!");
        address participant = msg.sender;
       
        _ERC20Token.burn(participant, tokensToSell);
        
        (bool sent, ) = msg.sender.call{value: tokensToSell * _tokenPrice}("");
        require(sent, "Failed to send Wei");        
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

    function getProposalInfo(uint idProp) external view votingIsOpen returns (string memory, string memory, uint) {                
        return (_proposals[idProp].getTitle(), _proposals[idProp].getDescription(), _proposals[idProp].getBudget());
    }

    function stake(uint idProp, uint numVotes, address proposal) external votingIsOpen partipicantExists {
        uint tokensInProposal = _proposals[idProp].getParticipantTokens(msg.sender);                
        uint t = (tokensInProposal + 1) / 2;
        uint nV = tokensInProposal;
        address participant = msg.sender;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (tokensInProposal / t + t) / 2;
        }

        //Calcular los tokens necesarios para depositar los votos que se van a depositar
        nV += numVotes;        
        uint tokensNeeded = (nV * nV) - tokensInProposal;

        // Comprobar que el participante posee los suficientes tokens para comprar los votos
        require(_ERC20Token.balanceOf(msg.sender) >= tokensNeeded, "Not enough tokens to vote the proposal!");
        
        // Comprobar que el participante ha cedido (con approve) el uso de esos tokens a la cuenta del contrato de la votacion
        require(_ERC20Token.allowance(msg.sender, proposal) >= tokensNeeded, "Not enough approved tokens!");

        // Depositar los tokens del participante a la propuesta
        _ERC20Token.transferFrom(participant, proposal, tokensNeeded);  // Da error
        _proposals[idProp].addParticipantVotes(tokensNeeded);

        // Comprobar si se puede ejecutar la propuesta
        // _checkAndExecuteProposal(idProp);
    }

    function withdrawFromProposal(uint numVotes, uint idProposal, address prop) external votingIsOpen {
        require(!_proposals[idProposal].isApproved(), "Proposal is already approved!");
        require(_proposals[idProposal].participantHasVotes(), "Participant does not have votes in proposal!");

        uint numTokensInProposal = _proposals[idProposal].getParticipantTokens(msg.sender);
        uint t = (numTokensInProposal + 1) / 2;
        uint nV = numTokensInProposal;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (numTokensInProposal / t + t) / 2;
        }

        // Devolver al participante los tokens que utilizó para depositar los votos que ahora retira
        uint tokensToWithdraw = numTokensInProposal - (numVotes * numVotes);
        _proposals[idProposal].withdrawParticipantVotes(tokensToWithdraw);

        _ERC20Token.transferFrom(prop, msg.sender, tokensToWithdraw);
    }

    function calculateThreshold(uint idProp) internal view returns (uint) {
        uint8 percentage = 20;
        uint threshold = ((percentage/100) + (_proposals[idProp].getBudget()/_totalBudget) * _numParticipants) + _pendingProposals.length; 
        return threshold;
    }

    function _checkAndExecuteProposal(uint idProp) internal {
        // Comprobar el presupuesto del contrato de votacion mas el importe recaudado por los votos 
        // recibidos es suficiente para financiar la propuesta
        // ¿?

        // Comprobar el número de votos recibidos supera un umbral
        uint tokensInProposal = _proposals[idProp].getParticipantTokens(msg.sender);                
        uint t = (tokensInProposal + 1) / 2;
        uint nV = tokensInProposal;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (tokensInProposal / t + t) / 2;
        }

        if (nV>calculateThreshold(idProp))
            IExecutableProposal(address(_proposals[idProp])).executeProposal{value: _proposals[idProp].getBudget(), gas: 100000}(idProp,nV,tokensInProposal);



    }

    // function closeVoting() external onlyOwner {
    //     //Realizar las tareas descritas en el enunciado
    //     //...

    //     // Inicializar las variables de estado para permitir
    //     // abrir un nuevo proceso de votaci n        
    //     _totalBudget = 0;
    //     _idProposal = 0;        
    //     _remainingWei = 0;
    //     _votingOpen = false;
    //     _votingClosed = false;
    // }
}