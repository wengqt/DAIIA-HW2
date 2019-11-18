/***
* Name: DifferentAuction
* Author: weng
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model DifferentAuction



global {
	Guests guest;
	list<Guests> refuser_list;
	list<Guests> proposer_list;
	
	int price <- rnd(150,200);
	
	init {
		
//		create Auctioneers_dutch number: 1;
		
		create Auctioneers_english number:1;
		create Guests number: 5;

	}
}

species Auctioneers_dutch skills: [fipa]{
	
	int min_price <-150;
//	int max_acceptable_price;
	int status <-1; //1 - no one buy it. 0-sold out.
	
	aspect default {
		draw rectangle(4, 4) color:#red;	
	}
	
	reflex startAuction when: (time = 2) {
//		Guests g <- Guests at 0;
		write 'Start Auction: ' + name + ' sends cfp msg to all guests participating in auction ';
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
		
	}
	
	reflex startAuction_inform when: (time = 1) {
//		Guests g <- Guests at 0;
		write 'Start inform: ' + name + ' sends inform of auction ';
		
		do start_conversation with: [to :: list(Guests), protocol :: 'no-protocol', performative :: 'query', contents :: ['Selling a shirt','Dutch'] ];
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
				do start_conversation with: [to :: proposer_list, protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
			}
				
		}else if status =0{
			do informAuctionEnd;

		}
	}
	
	
	action informAuctionEnd{
		do start_conversation with: [to :: list(proposer_list), protocol :: 'no-protocol', performative :: 'inform', contents :: ['end of auction'] ];
	
	}
	
	
	
	
	action comparePrice(message p,int price2){
		
		
		if(price2>=price and status =1){
			write '(Time ' + time + '): ' + name + ' accept propose from '+ agent(p.sender).name +'at price '+price;
			do accept_proposal with: [ message :: p, contents :: ['sell it at price'] ];
			status <-0;
		}else{
			write '(Time ' + time + '): ' + name + ' REJECT propose from '+ agent(p.sender).name +'at price '+price;
			do reject_proposal with: [ message :: p, contents :: ['reject'] ];
		}
	}
	
	
	

	
}


species Auctioneers_english skills:[fipa]{
	int min_price <- 150;
	Guests winner <- nil;
	int startTime <- nil;
	aspect default {
		draw rectangle(4, 4) color:#red;	
	}
	
	reflex startAuction_inform when: (time = 1){
		write 'auctioneer sends out auction information';
		do start_conversation with: [to :: list(Guests), protocol :: 'no-protocol', performative :: 'query', contents :: ['Selling a house','English'] ];
	}
	
	reflex startAuction when:(time = 2){
		write 'start auction';
		do start_conversation with: [to :: proposer_list, protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
//		waitForProposes <-true;
	}
	
	reflex recvProposal when:!empty(proposes){
		
		loop p over: proposes {

			string content <- p.contents[0];
			int p2 <- content as_int 10;
			
			if p2>price{
				price <- p2;
				winner <- Guests(agent(p.sender));
			}
			
		}
//		waitForProposes <- false;
		do broadcastPrice(price);
		
	}
	reflex noProposal when: empty(proposes) and startTime != nil and (time = startTime + 5){
		write 'no proposal time: '+ time;
		if(winner != nil){
			do start_conversation with: [to :: list(winner), protocol :: 'fipa-contract-net', performative :: 'accept_proposal', contents :: [price] ];
		}
		do start_conversation with: [to :: proposer_list, protocol :: 'fipa-contract-net', performative :: 'inform', contents :: ['END'] ];
	}
	
	action broadcastPrice(int newpirce){
		do start_conversation with: [to :: proposer_list, protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
//		waitForProposes <- true;
		write 'startTime: '+time;
		startTime <- time;
	}
	
	
	
	
	
	
	
}







species Guests skills: [fipa]{
	
	int status <-0; //0- end auction, 1- in auction.
	int my_price <-0 ;
	int auction_type <-0;
	aspect default {
		draw circle(2) color:#green;		
	}
	
	
	reflex recvAccept when: !(empty(accept_proposals)) and status=1{
		message msg <-accept_proposals[0];
		write '(Time ' + time + '): '+ name + ' buy from '+ agent(msg.sender).name +' at price '+ price;
		status<-0;
	}
	
	
	reflex recvReject when: !(empty(reject_proposals)) and status =1{
		message msg <-reject_proposals[0];
		write '(Time ' + time + '): '+name +' get reject from '+ agent(msg.sender).name+ ' '+ msg.contents[0];
//		status<-0;
	}
	
	reflex receiveCFP when: !(empty(cfps)) and auction_type=0 {
		message proposalFromInitiator <- cfps[0];
		

		if(self in proposer_list){
			if price < my_price{
				my_price <- price;
			}else{
				if my_price =0{
					my_price <- price - rnd(100);
				}
				
			}
			write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
			write 'log: ' + name + ' propose to ' + agent(proposalFromInitiator.sender).name + ' with price ' + price +' and bid for '+ my_price;
			do propose with: [ message :: proposalFromInitiator, contents :: [my_price] ];
		}else if(self in refuser_list){
			do refuse with: [ message :: proposalFromInitiator, contents :: ['not understood'] ];
		}
		
	}
	
	
	reflex receiveCFP_english when: !(empty(cfps)) and auction_type=1 {
		message proposalFromInitiator <- cfps[0];
		

		if(self in proposer_list){
			write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
			
			if(flip(0.5)){
				my_price <- price + rnd(50) ;
				write 'log: ' + name + ' propose to ' + agent(proposalFromInitiator.sender).name + ' with price ' + price +' and bid for '+ my_price;
				do propose with: [ message :: proposalFromInitiator, contents :: [my_price] ];
			}else{
				
			}
			
		}else if(self in refuser_list){
//			do refuse with: [ message :: proposalFromInitiator, contents :: ['not understood'] ];
		}
		
	}
	
	
	
	reflex recvInform when: !(empty(queries)){
		message msg <- queries[0];
		
		
		if(flip(0.7)){
			write 'log:'+ name+' is interested in proposal from '+ agent(queries[0].sender).name+' ' + msg.contents[1]; 
			add self to: proposer_list;
			if(msg.contents[1]='English'){
				auction_type <-1;
			}else if(msg.contents[1]='Dutch'){
				auction_type <-0;
			}
			status<-1;
		}else{
			write 'log:'+ name+' is NOT interested in proposal from '+ agent(queries[0].sender).name+' ' + msg.contents[1]; 
			add self to: refuser_list;
		}
//		write "length: "+ length(queries);
		do end_conversation with:[ message :: msg, contents :: ['we know'] ];
	}
	
	reflex recvInform2 when: !(empty(informs)){
		message msg <- informs[0];
		write '(Time ' + time + '): ' + name + ' receive from '+ agent(msg.sender).name +'about '+ msg.contents[0] ;
		status<-0;
		auction_type <-0;
		my_price <-0;
		do end_conversation with:[ message :: msg, contents :: ['end auction'] ];
		
	}
	
	
	
	
}

experiment fipa type:gui {
	output {
		display map {
			species Auctioneers_dutch;
			species Auctioneers_english;
			species Guests;
		}
	}
}