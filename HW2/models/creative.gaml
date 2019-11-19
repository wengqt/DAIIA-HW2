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
	list<Guests> refuser_list;
	list<Guests> proposer_list;
	Guests reject_proposal_participant;
	list<Guests> accept_proposal_participants ;
	Guests failure_participant;
	Guests inform_done_participant;
	Guests inform_result_participant;
	int price <- rnd(150,200);
//	int environment_size <-100;
	point auctionLocation <- {50, 50};
	int numberOfGuests <- 5;
//	geometry shape <- cube(environment_size);
	
	init {
		
		create Auctioneers number: 1 with: (location: auctionLocation) returns: g;
		create Guests number: numberOfGuests {
//			location <- {rnd(environment_size), rnd(environment_size), rnd(environment_size)};
		}
		create Security_Guard number: 1;
		guest <- Guests(g at 0);
	}
}

species Auctioneers skills: [fipa]{
	
	int min_price <-100;
//	int max_acceptable_price;
	int status <-1; //1 - no one buy it. 0-sold out. 2 - buyer has no money
	
	aspect default {
		draw cube(4) color:#red;	
	}
	
	reflex startAuction when: (time = 2) {
//		Guests g <- Guests at 0;
		write 'Start Auction: ' + name + ' sends cfp msg to all guests participating in auction ';
		do start_conversation with: [to :: list(Guests), protocol :: 'fipa-contract-net', performative :: 'cfp', contents :: ['Sell for price: ' + price] ];
		
	}
	
	reflex startAuction_inform when: (time = 1) {
//		Guests g <- Guests at 0;
		write 'Start inform: ' + name + ' sends inform of auction ';
		
		do start_conversation with: [to :: list(Guests), protocol :: 'no-protocol', performative :: 'query', contents :: ['Selling a shirt '] ];
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
			ask Guests(agent(p.sender)) {
				if(self.outOfCash = true){
					status <- 2;
					do start_conversation with: [to :: list(Security_Guard), protocol :: 'no-protocol', performative :: 'inform', contents :: [agent(p.sender).location] ];
				}
			}
			status <-0;
		}else{
			write '(Time ' + time + '): ' + name + ' REJECT propose from '+ agent(p.sender).name +'at price '+price;
			do reject_proposal with: [ message :: p, contents :: ['reject'] ];
		}
	}
	
	
	

	
}

species Guests skills: [fipa, moving]{
	
	int status <-0; //0- end auction, 1- in auction, 2 - out of money
	int my_price <-0 ;
	bool won <- false;
	bool outOfCash <- flip(0.9);
//	aspect default {
//		draw circle(2) color:#green;		
//	}
	
	aspect default {
        draw sphere(1) color: #green;   
    }
	
	reflex statusIdle //when: statusPoint = nil 
	{
		do wander;
	}
	
	
	reflex recvAccept when: !(empty(accept_proposals)) and status=1{
		message msg <-accept_proposals[0];
		
		if(outOfCash = false) {
			write '(Time ' + time + '): '+ name + ' buy from '+ agent(msg.sender).name +' at price '+ my_price;
			status<-0;
			won <- true;
		}else {
			write '(Time ' + time + '): '+ name + ' out of MONEY '+ agent(msg.sender).name +' can not pay price: '+ my_price;
			status <- 2;
		}

	}
	
	
	reflex recvReject when: !(empty(reject_proposals)) and status =1{
		message msg <-reject_proposals[0];
		write '(Time ' + time + '): '+name +' get reject from '+ agent(msg.sender).name+ ' '+ msg.contents[0];
//		status<-0;
	}
	
	reflex receiveCFP when: !(empty(cfps)) {
		message proposalFromInitiator <- cfps[0];
		
		//do goto target:auctionLocation;
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
	
	
	
	reflex recvInform when: !(empty(queries)){
		message msg <- queries[0];
		
		
		if(flip(0.7)){
			write 'log:'+ name+' is interested in proposal from '+ agent(queries[0].sender).name; 
			add self to: proposer_list;
			status<-1;
		}else{
			write 'log:'+ name+' is NOT interested in proposal from '+ agent(queries[0].sender).name; 
			add self to: refuser_list;
		}
//		write "length: "+ length(queries);
		do end_conversation with:[ message :: msg, contents :: ['we know'] ];
	}
	
	reflex recvInform2 when: !(empty(informs)){
		message msg <- informs[0];
		write '(Time ' + time + '): ' + name + ' receive from '+ agent(msg.sender).name +'about '+ msg.contents[0] ;
		status<-0;
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

species Security_Guard skills:[fipa, moving]{
	point my_location;
	Guests target <- nil;
	int status <-0; //0-> wander, 1-> follow guest,2 ->do job, 3-> go back;
	aspect default {
		draw sphere(3) color: #gray;
	}
	init{
		my_location<- location;
	}
	
//	reflex dowander when: status=0{
//		do wander;
//	}
	
	reflex receiveInfo when: !(empty(informs)) {
		message removeGuest <- informs[0];
		
		//loop in over: inform {
			point guestLocation <- removeGuest.contents[0];		
			do goto target:guestLocation;
			ask one_of(Guests){
				do die;
			}
			write "Guest with no money has been removed from the Auction";
			status <- 3;
		//}
	}

//	reflex follow_guest when: status=1{
//		do goto target:target;
////		status <- 2;
////		write target;
//	}
//	reflex withbadGuy when:target !=nil and location distance_to target <5{
//		status<-2;
//		
//	}
//	reflex doJob when: status=2{
//		ask one_of (target){
//				//if (myself.status = 3) {
//					write "guard removes bad guy";
//					do die;
//				//}
//				//self.status<-3;
//				
//		}
//		status <- 3;
//	}
	
	reflex goback when: status=3{
		do goto target:my_location;
	}
	
	
	
}

experiment fipa type:gui {
	parameter "number of guests: " var: numberOfGuests;
	output {
		display map type:opengl{
			species Auctioneers;
			species Guests;
			species Security_Guard;
		}
		
		display auction_chart {
			chart "testing" {
				data "test" value: length (Guests where (each.won = true));
			}
		}
	}
}