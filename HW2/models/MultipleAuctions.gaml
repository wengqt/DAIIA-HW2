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
		create Auctioneers number: 1 with: (type: "clothes") returns: g;
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
	
	aspect default {
		draw rectangle(4, 4) color: (type = "clothes")? #red : #blue;	
	}
	
	reflex startAuction_inform when: (time = 1) {
		write 'Informing auction: ' + name + ' starting of type: ' + type + ' (sends cfp msg to all guests)';
		
		do start_conversation with: [to :: list(Guests), protocol :: 'no-protocol', performative :: 'query', contents :: ['Selling: '+ type] ];
	}
	
	reflex startAuction when: (time = 2) {
		write 'Starting auction: ' + name + ' starting of type: ' + type + ' and starting price: ' + price + ' (sends cfp msg to all guests)';
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Selling: ' + type + ' for price: ' + price] ];	
		
	}
	
	reflex receiveProposal when: !empty(proposes){
//		write '(Time ' + time + '): ' + name + ' receives propose messages';
		
		loop p over: proposes {

			string content <- p.contents[0];
			int p2 <- content as_int 10;

			do comparePrice(p, p2);
			
		}
		
		if status =1{
			if price = min_price {
				do informAuctionEnd;
				return;
			}else{
				price <- price - 10;
				if price < min_price{
					price <- min_price;
				}
				write '(Time ' + time + '): ' + name + ' start a new cfp at price '+price;
				do start_conversation with: [to :: guests, protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
			}
				
		}else if status =0{
			do informAuctionEnd;

		}
	}
	
	
	action informAuctionEnd{
		do start_conversation with: [to :: guests, protocol :: 'no-protocol', performative :: 'inform', contents :: ['end of auction'] ];
	
	}
	
	
	
	
	action comparePrice(message p,int price2){
		
		
		if(price2>=price and status =1){
			write '(Time ' + time + '): ' + name + ' accept propose from '+ agent(p.sender).name +' at price '+price;
			do accept_proposal with: [ message :: p, contents :: ['sell it at price'] ];
			status <-0;
		}else{
			write '(Time ' + time + '): ' + name + ' REJECT propose from '+ agent(p.sender).name +' at price '+price;
			do reject_proposal with: [ message :: p, contents :: ['reject'] ];
		}
	}
	
	
	

	
}

species Guests skills: [fipa]{
	
	int status <-0; //0- end auction, 1- in auction.
	int my_price <-0 ;
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
			
			if auction.price < my_price{
				my_price <- auction.price;
			}else{
				if my_price = 0{
					my_price <- auction.price - rnd(10);
				}
			}
			write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + auction.name + ' with content ' + proposalFromInitiator.contents;
			write 'log:'+ name+' is interested in '+ interest +' proposal from '+ auction.name + ' and bid for '+ my_price;
			do propose with: [ message :: proposalFromInitiator, contents :: [my_price] ];
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