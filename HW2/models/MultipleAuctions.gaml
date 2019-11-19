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
		
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'inform', contents :: ['Start auction selling: '+ type,'start'] ];
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
//			write '(Time ' + time + '): ' + name + ' get proposal from'+agent(p.sender).name +' at bid price '+price;
			do comparePrice(p, p2);
			
		}
		
		if status =1{
			if price = min_price {
				write name +'1';
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
			write name + '2';
			do informAuctionEnd;

		}
	}
	
	
	action informAuctionEnd{
		do start_conversation with: [to :: guests, protocol :: 'fipa-contract-net', performative :: 'inform', contents :: ['end of auction '+type] ];
	
	}
	
	
	
	
	action comparePrice(message p,int price2){
		
		
		if(price2>=price and status =1){
			write '(Time ' + time + '): ' + name + ' accept propose from '+ agent(p.sender).name +' at price '+price2;
			do accept_proposal with: [ message :: p, contents :: ['sell it at price'] ];
			status <-0;
		}else{
			write '(Time ' + time + '): ' + name + ' REJECT propose from '+ agent(p.sender).name +' at price '+price2;
			do reject_proposal with: [ message :: p, contents :: ['reject'] ];
		}
	}
	
	
	

	
}

species Guests skills: [fipa]{
	
	int status <-0; //0- end auction, 1- in auction.
	int my_price <-0 ;
	string interest <- interestTypes[rnd(length(interestTypes) - 1)];
	Auctioneers auction<-nil;
	int endTime<-0;
	
	aspect default {
//		write '+'+endTime;
		if ((interest='cds' and status =1) or ((interest='cds' and auction !=nil) ))	{
			draw circle(2) color:#blue;	
		}else if((interest='clothes' and (status =1) or ((interest='clothes' and auction !=nil)))){
			draw circle(2) color:#red;	
		}else{
			draw circle(2) color:#green;	
		}
	}
	

	reflex recvAccept when: !(empty(accept_proposals)) and status = 1{
		write name + " receive ACCEPT";
		message msg <-accept_proposals[0];
		Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
		write '(Time ' + time + '): '+ name + ' buy from '+ agent(msg.sender).name +' at price '+ my_price;
//		status<-0;
		remove self from: informingAuction.guests;
		//auction <- nil;
	}
	
	
	reflex recvReject when: !(empty(reject_proposals)) and status =1{
		message msg <-reject_proposals[0];
		Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
		write '(Time ' + time + '): '+name +' get reject from '+ agent(msg.sender).name+ ' '+ msg.contents[0];
//		status<-0;
		remove self from: informingAuction.guests;
	}
	
	reflex receiveCFP when: !(empty(cfps))  {
		message proposalFromInitiator <- cfps[0];
		
		
		Auctioneers auctionInitiator <- Auctioneers(proposalFromInitiator.sender);
		
		write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + auctionInitiator.name + ' with content ' + proposalFromInitiator.contents;
			
		if (auctionInitiator.type = interest){
			status<-1;
			auction <- auctionInitiator;
			auction.guests <+ self;
			
			if auction.price < my_price{
				my_price <- auction.price;
			}else{
				if my_price = 0{
					my_price <- auction.price - rnd(10);
				}
			}
			write '(Time ' + time + '): ' + name+' is interested in '+ interest +' proposal from '+ auction.name + ' and bid for '+ my_price;
			do propose with: [ message :: proposalFromInitiator, contents :: [my_price] ];
		} else {
			write '(Time ' + time + '): ' + name+' is NOT interested in proposal of '+auctionInitiator.type;
			do refuse with: [ message :: proposalFromInitiator, contents :: ['not understood'] ];
		}
		
		
	}
	
	reflex recvInformEnd when: !(empty(informs)) and status = 1{
		message msg <- informs[0];
		Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
		
		write '(Time ' + time + '): ' + name + ' receive from '+ informingAuction.name +' about '+ msg.contents[0] ;
		status<-0;
		remove self from: informingAuction.guests;
		
		endTime<- int(time+2);
//		do end_conversation with:[ message :: msg, contents :: ['end auction'] ];
		
	}
	
	reflex endAction when: endTime!=0 and time=endTime{
		auction <- nil;
		
	}
	
	
	
	reflex recvInformStart when: !(empty(informs)) and status = 0 {
		message msg <- informs[0];
		if(length(msg.contents)>1 and msg.contents[1]='start'){
			Auctioneers informingAuction <- Auctioneers(agent(msg.sender));
			if(informingAuction.type = interest){
				auction <- informingAuction;
			}
			write '(Time ' + time + '): ' + name + ' receive from '+ informingAuction.name +' about '+ msg.contents[0] ;
		}
		
//		status<-0;
//		remove self from: informingAuction.guests;
//		auction <- nil;
//		do end_conversation with:[ message :: msg, contents :: ['end auction'] ];
		
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