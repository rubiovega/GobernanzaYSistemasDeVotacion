// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./ERC20/ERC20.sol";
import "./ERC20/ERC20Token.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;    
}

contract ExecutableProposal is IExecutableProposal {
    event ProposalExecution(string msg, uint id, uint votes, uint tokens, uint budget);

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override {
        emit ProposalExecution("Executing proposal with data (id, votes, tokens, budget): ", proposalId, numVotes, numTokens, msg.value);
    }
}

contract Proposal {    
    string _title;   // Titulo de la propuesta
    string _description;    // Descripcion de la propuesta
    uint _budget;           // Presupuesto de la propuesta
    address _creator;       // Creador de la propuesta
    bool _approved;         //  Booleano que indica si la propuesta ha sido o no aprobadas
    uint _numTokens;  // Numero de tokens recaudados por el proposal
    uint _numVotes;  // Numero de votos que tiene la propuesta
    address[] _addressParticipants; // Array que contiene los address de los participantes que votan la propuesta
    mapping (address => uint) _participantTokens; // Mapping cuya clave es el address del participante y valor los tokens que ha
                                                  // depositado en la propuesta
    address _executableProposal;    // Direccion que implementa la interfaz IExecutableProposal

    constructor(string memory title, string memory description, uint budget, address creator, address execProp) {
        _title = title;
        _description = description;
        _budget = budget;
        _creator = creator;         
        _approved = false;
        _numTokens = 0;
        _numVotes = 0;
        _executableProposal = execProp;
    }

    function isApproved() external view returns (bool) {
        return _approved;
    }

    function getParticipantsAddresses() external view returns (address[] memory) {
        return _addressParticipants;
    }

    function getParticipantTokens(address participant) external view returns (uint) {
        return _participantTokens[participant];
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

    function getNumVotes() external view returns (uint) {
        return _numVotes;
    }

    function getExecutableProposal() external view returns (address) {
        return _executableProposal;
    }

    function approveProposal() external {
        _approved = true;
    }

    function addParticipantVotes(address participant, uint nV, uint nT) external {
        if(_participantTokens[participant] == 0) {
            _addressParticipants.push(participant);
        }

        _participantTokens[participant] = _participantTokens[participant] + nT;        
        _numTokens = _numTokens + nT;
        _numVotes = _numVotes + nV;
    }

    function withdrawParticipantVotes(address participant, uint nV, uint tokensToWithdraw) external {       
        _participantTokens[participant] = _participantTokens[participant] - tokensToWithdraw;
        _numVotes = _numVotes - nV;
        _numTokens = _numTokens - tokensToWithdraw;
        
        // Si el participante deja de tener tokens, se borra de la propuesta
        if(_participantTokens[participant] == 0) {            
            uint pos = 0;

            while(_addressParticipants[pos] != participant)
                pos++;

            for(uint i = pos; i < _addressParticipants.length - 1; i++)
                _addressParticipants[i] = _addressParticipants[i+1];

            _addressParticipants.pop();
        }
    }
}

contract QuadraticVoting {    
    address _owner;  // Contract owner.    
    uint _maxTokens;    // Numero de tokens total
    uint _tokenPrice;   // Precio del token
    string _name;       // Nombre del token
    string _symbol;     // Simpobolo del token
    ERC20Token _ERC20Token;  // ERC20Token contract
    bool public _votingOpen; // Booleano que indica si la votacion esta abierta
    uint _totalBudget;  // Presupuesto del que se dispone para financiar propuestas
    uint _numParticipants;  // Numero de participantes registrados
    
    uint _idProposal;   // Identificador de la ultima propuesta registrada
    mapping (uint => Proposal) _proposals;  // Mapping que contiene como clave el identificador de la 
                                            // propuesta y como valor el contrato de cada Proposal,
                                            // siendo 1 el id de la primera propuesta, el 2 el de la segunda propuesta...
    uint[] _pendingProposals;   // Array con los identificadores de las propuestas pendientes
    uint[] _approvedProposals;   // Array con los identificadores de las propuestas aprovadas
    uint[] _signalingProposals;   // Array con los identificadores de las propuestas signaling
    mapping (address => bool) _participants;    // Mapping de participantes que almacenan la direccion y 
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
        _numParticipants = 0;
         _remainingWei = 0;
        _votingOpen = false;
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

    // Modifier que comprueba si un participante esta  inscrito 
    modifier participantExists() {
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
        if(!_votingOpen) {
            _votingOpen = true;
            _totalBudget = msg.value;
        }
    }

    function addParticipant() external payable enoughWeiToBuyAToken {
        require(!_participants[msg.sender], "Participant already exists!");
        _numParticipants++;
        _participants[msg.sender] = true;
        
        uint amount = msg.value / _tokenPrice;
        _remainingWei = _remainingWei + msg.value % _tokenPrice;    // La cantidad de Wei sobrante se la 
                                                                    // queda el owner como propina    
        _ERC20Token.mint(msg.sender, amount);    
    }

    function addProposal(string memory title, string memory description, uint budget, address execProp) external votingIsOpen participantExists returns (uint) {
        _idProposal++;
        _proposals[_idProposal] = new Proposal(title, description, budget, msg.sender, execProp);

        // Si la propuesta es de financiacion, anadimos la propuesta al array de _pendingProposals             
        if(budget != 0) {
            _pendingProposals.push(_idProposal);
        }
        // Si la propuesta es signaling, anadimos la propuesta al array de _signalingProposals
        else {
            _signalingProposals.push(_idProposal);
        }
        return _idProposal;
    }

    function cancelProposal(uint idProp) external votingIsOpen {
        require (msg.sender == _proposals[idProp].getCreator(), "Not the proposal creator!");            
        require(!_proposals[idProp].isApproved(), "Can't cancel an approved proposal!");                
        
        // Si es una propuesta de financiacion, eliminamos la propuesta
        // del array de _pendingProposals
        if(_proposals[idProp].getBudget() != 0) {
           deletePendingProposal(idProp);
        }
        // Si es una propuesta de signaling, eliminamos la propuesta
        // del array de _signalingProposals
        else {
            deleteSignalingProposal(idProp);
        }
                        
        address[] memory addressParticipants = _proposals[idProp].getParticipantsAddresses();
        
        // Retirar los tokens de los participantes de la propuesta
        for(uint i = 0; i < addressParticipants.length; i++) {
            uint participantTokensInProposal = _proposals[idProp].getParticipantTokens(addressParticipants[i]);

            // Depositar los tokens de QuadraticVoting al participante
            _ERC20Token.transfer(addressParticipants[i], participantTokensInProposal);
        }

        // Borrar propuesta del mapping _proposals
        delete _proposals[idProp];                
    }
    
    function buyTokens(uint tokensToBuy) public payable participantExists enoughWeiAmount(tokensToBuy) { 
        _ERC20Token.mint(msg.sender, tokensToBuy);        
        _remainingWei = _remainingWei + msg.value - _tokenPrice * tokensToBuy;        
    }

    function sellTokens(uint tokensToSell) external participantExists {        
        require(_ERC20Token.balanceOf(msg.sender) >= tokensToSell, "Participant does not have enough tokens to sell!");
        address participant = msg.sender;

        _ERC20Token.burn(participant, tokensToSell);
        
        (bool sent,) = msg.sender.call{value: tokensToSell * _tokenPrice}("");
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

    function stake(uint idProp, uint numVotes) external votingIsOpen participantExists {
        require(!_proposals[idProp].isApproved(), "Proposal already approved!");

        uint tokensInProposal = _proposals[idProp].getParticipantTokens(msg.sender);                
        uint t = (tokensInProposal + 1) / 2;
        uint nV = tokensInProposal;
        
        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (tokensInProposal / t + t) / 2;
        }

        //Calcular los tokens necesarios para depositar los votos que se van a depositar
        nV = nV + numVotes;        
        uint tokensNeeded = (nV * nV) - tokensInProposal;

        // Comprobar que el participante posee los suficientes tokens para comprar los votos
        require(_ERC20Token.balanceOf(msg.sender) >= tokensNeeded, "Not enough tokens to vote the proposal!");
        
        // Comprobar que el participante ha cedido (con approve) el uso de esos tokens a la cuenta del contrato de la votacion
        require(_ERC20Token.allowance(msg.sender, address(this)) >= tokensNeeded, "Not enough approved tokens!");

        // Depositar los tokens del participante a QuadraticVoting
        _ERC20Token.transferFrom(msg.sender, address(this), tokensNeeded);
        _proposals[idProp].addParticipantVotes(msg.sender, numVotes, tokensNeeded);

        // Comprobar si la propuesta es de financiacion y si se puede ejecutar la propuesta
        if(_proposals[idProp].getBudget() != 0)
            _checkAndExecuteProposal(idProp);
    }

    function withdrawFromProposal(uint numVotes, uint idProp) external votingIsOpen participantExists {
        require(!_proposals[idProp].isApproved(), "Proposal is already approved!");

        uint numTokensInProposal = _proposals[idProp].getParticipantTokens(msg.sender);

        require(numTokensInProposal != 0, "Participant does not have tokens in this proposal!");
                
        uint t = (numTokensInProposal + 1) / 2;
        uint nV = numTokensInProposal;

        // Calcular cuantos votos tiene el participante en la propuesta
        while(t < nV) {
            nV = t;
            t = (numTokensInProposal / t + t) / 2;
        }

        // Retirar los tokens que ha depositado el participante en la propuesta
        uint tokensToWithdraw = numTokensInProposal - (numVotes * numVotes);
        
        require(numTokensInProposal >= tokensToWithdraw, "Can't withdraw that amount of tokens!");
        _proposals[idProp].withdrawParticipantVotes(msg.sender, numVotes, tokensToWithdraw);

        _ERC20Token.transfer(msg.sender, tokensToWithdraw);
    }

    function calculateThreshold(uint idProp) internal view returns (uint) {
        uint8 percentage = 20;
        uint threshold =  _pendingProposals.length + _signalingProposals.length + _numParticipants * percentage/100 + _proposals[idProp].getBudget()/_totalBudget;
        return threshold;
    }

    function _checkAndExecuteProposal(uint idProp) internal {
        // Comprobar el presupuesto del contrato de votacion mas el importe recaudado por los votos 
        // recibidos es suficiente para financiar la propuesta
        uint numTokens = _proposals[idProp].getNumTokens();
        uint budget = _proposals[idProp].getBudget();
        uint numVotes = _proposals[idProp].getNumVotes();

        if(_totalBudget + numTokens * _tokenPrice >= budget) {
            // Si el numero de votos recibidos supera un umbral, ejecutamos la propuesta
            if (numVotes >= calculateThreshold(idProp)) {          
                
                // Actualizar el presupuesto disponible para propuestas
                _totalBudget = _totalBudget + numTokens * _tokenPrice - budget;
                
                // Eliminar propuesta del array de _pendingProposals                
                deletePendingProposal(idProp);
                
                // Indicar la propuesta como aprobada
                _proposals[idProp].approveProposal();

                // Anadir propuesta al array de _approvedProposals
                _approvedProposals.push(idProp);
                
                // Ejecutar la propuesta
                IExecutableProposal(address(_proposals[idProp].getExecutableProposal())).executeProposal{value: budget, gas: 100000}(idProp, numVotes, numTokens);            
            }
        }
    }

    function closeVoting() external onlyOwner {        
        Proposal p;
        uint i;
        uint j;
        uint k;
        address[] memory addressParticipants;
        uint participantTokensInProposal;

        // Devolver a los participantes los tokens recibidos en aquellas propuestas de 
        // financiacion que no han sido aprobadas
        for(i = 0; i < _pendingProposals.length; i++) {
            p = _proposals[_pendingProposals[i]];            
            addressParticipants = p.getParticipantsAddresses();

            // Retirar los tokens de los participantes de la propuesta
            for(j = 0; j < addressParticipants.length; j++) {
                participantTokensInProposal = p.getParticipantTokens(addressParticipants[j]);

                // Depositar los tokens de QuadraticVoting al participante
                _ERC20Token.transfer(addressParticipants[j], participantTokensInProposal);
            }        
        }

        // Eliminar los identificadores del array _pendingProposals
        uint pendLength = _pendingProposals.length;

        for(k = 0; k < pendLength; k++)
            _pendingProposals.pop();

        // Ejecutar las propuestas signaling y devolver los tokens recibidos a sus propietarios
        for(i = 0; i < _signalingProposals.length; i++) {
            p = _proposals[_signalingProposals[i]];            
            addressParticipants = p.getParticipantsAddresses();

            // Retirar los tokens de los participantes de la propuesta
            for(j = 0; j < addressParticipants.length; j++) {
                participantTokensInProposal = p.getParticipantTokens(addressParticipants[j]);

                // Depositar los tokens de QuadraticVoting al participante
                _ERC20Token.transfer(addressParticipants[j], participantTokensInProposal);
            }

            _proposals[_signalingProposals[i]].approveProposal();
            _approvedProposals.push(_signalingProposals[i]);

            IExecutableProposal(address(p.getExecutableProposal())).executeProposal{value: 0, gas: 100000}(_signalingProposals[i], p.getNumVotes(), p.getNumTokens());
        }

        // Eliminar los identificadores del array _signalingProposals
        uint signLength = _signalingProposals.length;

        for(k = 0; k < signLength; k++)
            _signalingProposals.pop();

        // Eliminar los identificadores del array _approvedProposals
        uint apprLength = _approvedProposals.length;

        for(k = 0; k < apprLength; k++)
            _approvedProposals.pop();

        // Inicializar las variables de estado para permitir
        // abrir un nuevo proceso de votacion        
        _totalBudget = 0;
        _idProposal = 0;        
        _remainingWei = 0;
        _votingOpen = false;

        // El presupuesto de la votación no gastado en las propuestas se transfiere
        // al propietario del contrato de votación y también la propina que ha recibido a lo largo del proceso
        // de votación
        (bool sent,) = msg.sender.call{value: _totalBudget + _remainingWei}("");
        require(sent, "Failed to send Wei");    
    }

    // Funcion interna para eliminar una propuesta del array de _pendingProposals
    function deletePendingProposal(uint idProp) internal {
        uint pos = 0;

        while(_pendingProposals[pos] != idProp)
                pos++;

        for(uint i = pos; i < _pendingProposals.length-1; i++) 
            _pendingProposals[i] = _pendingProposals[i+1];
    
        _pendingProposals.pop();
    }

    // Funcion interna para eliminar una propuesta del array de _signalingProposals
    function deleteSignalingProposal(uint idProp) internal {
        uint pos = 0;
        while(_signalingProposals[pos] != idProp)            
                pos++;

            for(uint i = pos; i < _signalingProposals.length-1; i++)
                _signalingProposals[i] = _signalingProposals[i+1];

            _signalingProposals.pop();
    }
}