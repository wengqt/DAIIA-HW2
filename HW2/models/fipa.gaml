/***
* Name: fipa
* Author: sigrunarnasigurdardottir
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model fipa

/* Insert your model definition here */

global {
	Guests guest;
	Guests refuser;
	list<Guests> proposers;
	Guests reject_proposal_participant;
	list<Guests> accept_proposal_participants ;
	Guests failure_participant;
	Guests inform_done_participant;
	Guests inform_result_participant;
	
	init {
		create Guests number: 15;
		create Auctioneers number: 2 returns: g;
		//guest <- Guests(g at 0);
	}
}

species Auctioneers skills: [fipa]{
	
	aspect default {
		draw rectangle(4, 4) color:#red;	
	}
	
	reflex startAuction when: (time = 1) {
		Guests g <- Guests at 1;
		write 'Start Auction: ' + name + ' sends cfp msg to all guests participating in auction ';
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + 'set price variable here'] ];
		
	}
	
	
	reflex readMsgAgree when: !(empty(agrees)) {
		loop agree over: agrees {
			write 'agree content: ' + string(agree.contents);
		}
	}
	
	reflex readMsgFail when: !(empty(failures)) {
		loop fail over: failures {
			write 'failed msg: ' + (string(fail.contents));
		}
	}
	
}

species Guests skills: [fipa]{
	
	aspect default {
		draw circle(2) color:#green;		
	}
	
	reflex receiveCFP when: !(empty(cfp)) {
		//message proposalFromInitiator <- cfps[0];
		//write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
		
//		if (self = refuser) {
//			write '\t' + name + ' sends a refuse message to ' + agent(proposalFromInitiator.sender).name;
//			do refuse with: [ message :: proposalFromInitiator, contents :: ['I am busy today'] ];
//		}
//		
//		if (self in proposers) {
//			write '\t' + name + ' sends a propose message to ' + agent(proposalFromInitiator.sender).name;
//			do propose with: [ message :: proposalFromInitiator, contents :: ['Ok. That sound interesting'] ];
//		}
	}
	
	reflex replyOnBid when: !(empty(requests)) {
		message requestFromInitatior <- (requests at 0);
		
		do agree with: (message: requestFromInitatior, contents: ['Agreee']);
		
		write 'failure, inform auctioneer';
		do failure (message: requestFromInitatior, contents: ['broken']);
	}
}

experiment fipa type:gui {
	output {
		display map {
			species Auctioneers;
			species Guests;
		}
	}
}