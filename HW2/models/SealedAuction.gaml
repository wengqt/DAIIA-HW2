/***
* Name: fipa
* Author: sigrunarnasigurdardottir
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model fipa

/* Insert your model definition here */

global {
	list<string> interestTypes <- ["cds", "clothes", nil];
	
	init {
		
		create Auctioneers number: 1 with: (type: "cds") returns: g;
		create Guests number: 10;
		
		//list<Auctioneers> clothes <- Auctioneers where (each.type="clothes");
    	//list<Auctioneers> cds <- Auctioneers where (each.type="cds");
	}
}

species Auctioneers skills: [fipa]{
	string type;
	list<Guests> guests;
	int price <- rnd(20, 150);
	int min_price <-60;
//	int max_acceptable_price;
	int status <-1; //1 - no one buy it. 0-sold out.
	int maxPrice <- 0;
	//message winner <- nil;
	Guests winner <- nil;
	
	aspect default {
		draw rectangle(4, 4) color: (type = "clothes")? #red : #blue;	
	}
	
	reflex startAuction_inform when: (time = 1) {
		write 'Informing auction: ' + name + ' starting of type: ' + type;
		
		do start_conversation with: [to :: list(Guests), protocol :: 'no-protocol', performative :: 'query', contents :: ['Selling: '+ type] ];
	}
	
	reflex startAuction when: (time = 2) {
		write 'Starting auction: ' + name + ' starting of type: ' + type + ' (sends cfp msg to all guests)';
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Selling: ' + type + ' Please place your bid'] ];	
		
	}
	
	reflex receiveProposal when: !empty(proposes){
		
//		write '(Time ' + time + '): ' + name + ' receives propose messages';
		
//		loop p over: proposes {
//

//
////			do comparePrice(p, p2);
//			
//		}
		loop p over: proposes {
			string content <- p.contents[0];
			int p2 <- content as_int 10;
			write name + ' got an offer from ' + p.sender + ' of ' + p.contents[0];
			if(p2 > maxPrice) {
				maxPrice <- p2;
				winner <- Guests(agent(p.sender));
				write ''+winner.name;
			}
		}
		
		do start_conversation (to: list(winner), protocol: 'fipa-contract-net', performative: 'accept_proposal', contents: ['win']);
		write name + ' bid ended. Sold to ' + winner.name;
		//do accept_proposal with: (message: winner2, contents: ['Congrats you won!']);
		do start_conversation (to: guests, protocol: 'fipa-contract-net', performative: 'reject_proposal', contents: ["stop bid"]);
		guests <- [];
	}
	
	
}

species Guests skills: [fipa]{
	
	int status <-0; //0- end auction, 1- in auction.
	int my_price <- rnd(200) ;
	string interest <- interestTypes[rnd(length(interestTypes) - 1)];
	Auctioneers auction;
	
	aspect default {
		draw circle(2) color:#green;		
	}
	

	reflex recvAccept when: !(empty(accept_proposals)) and status = 1{
		write "receive ACCEPT";
		message msg <-accept_proposals[0];
		Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
		write '(Time ' + time + '): '+ name + ' buy from '+ agent(msg.sender).name +' at price '+ my_price;
		status<-0;
		remove self from: informingAuction.guests;
		//auction <- nil;
	}
	
	
	reflex recvReject when: !(empty(reject_proposals)) and status =1{
		message msg <-reject_proposals[0];
		write '(Time ' + time + '): '+name +' get reject from '+ agent(msg.sender).name+ ' '+ msg.contents[0];
		status<-0;
	}
	
	reflex receiveCFP when: !(empty(cfps)) {
		message proposalFromInitiator <- cfps[0];
		
		
		Auctioneers auctionInitiator <- Auctioneers(proposalFromInitiator.sender);
		
		
		if (auctionInitiator.type = interest){
			auction <- auctionInitiator;
			auction.guests <+ self;
			status <- 1;

			//write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + auction.name + ' with content ' + proposalFromInitiator.contents;
			write 'log:'+ name+' is interested in '+ interest +' proposal from '+ auction.name + ' and bid for '+ my_price;
			do start_conversation (to: proposalFromInitiator.sender, protocol: 'fipa-propose', performative: 'propose', contents: [my_price]);
			auction <- nil;
		} else {
			write 'log:'+ name+' is not interested in proposal';
			do refuse with: [ message :: proposalFromInitiator, contents :: ['not understood'] ];
		}
		
		
	}
	
	reflex recvInformEnd when: !(empty(informs)){
		message msg <- informs[0];
		Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
		
		write '(Time ' + time + '): ' + name + ' receive from '+ informingAuction.name +'about '+ msg.contents[0] ;
		status<-0;
		remove self from: informingAuction.guests;
		auction <- nil;
		do end_conversation with:[ message :: msg, contents :: ['end auction'] ];
		
	}
	
	
	
	
//	reflex replyOnBid when: !(empty(requests)) {
//		message requestFromInitatior <- (requests at 0);
//		
//		do agree with: (message: requestFromInitatior, contents: ['Agreee']);
//		
//		write 'failure, inform auctioneer';
//		do failure (message: requestFromInitatior, contents: ['broken']);
//	}
}

experiment fipa type:gui {
	output {
		display map {
			species Auctioneers;
			species Guests;
		}
	}
}