#include<stdio.h>
#include<conio.h>
int b[10][10];
int i,p,q;
int j;
void matrix(int);
int main ()
{
	int n, a[10][10] , c[10][10];

    char option = 'y';
 do {
 
    printf("\nwhat operation u want to do \n");
   	printf("enter 1: to transpose, 2: to upper and lower triangle, 3: for addition, 4: to subtraction, 5: multiplication\n ");
    
	scanf("%d",&n);
    
   	printf("enter elements of a matrix :\n");
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { scanf("%d",&a[i][j]);}}
    printf("entered value in matrix are:\n");
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { printf("%d\t",a[i][j]);} 
    printf("\n"); } 
    


switch(n)

{
	case 1: 
 
	printf("transpose of entered matrix\n");
	for(j=1;j<=3;j++)
  { for(i=1;i<=3;i++)
  { printf("%d\t",a[i][j]);} 
    printf("\n"); } 
	break;
	

	case 2:
    printf("upper triangle of given matrix :\n");
    
	for(i=1;i<=3;i++)
  {
  { for(j=1;j<=3;j++)
    if(j>=i)
    printf("%d\t",a[i][j]);
    else 
    printf("\t"); }
    printf("\n"); }	
    printf("And lower triangle of given matrix :\n");
    
	for(i=1;i<=3;i++)
  {
  { for(j=1;j<=3;j++)
    if(j<=i)
    printf("%d\t",a[i][j]);
    else 
    printf("\t"); }
    printf("\n"); }
    break;
   
   
    case 3:
	matrix();
	printf("addition of given matrix :\n");
    
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { c[i][j] = a[i][j] + b[i][j];
  
    printf("%d\t",c[i][j]);} 
    printf("\n"); }
	break;


	case 4:
	matrix();
	
	printf("subtraction  of given matrix :\n");
    
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { c[i][j] = a[i][j] - b[i][j];
  
    printf("%d\t",c[i][j]);} 
    printf("\n"); }
	break;
	
	case 5:    
	matrix();	
	printf("multiplication  of given matrix :\n");
	
	for( p=1; p<=3;p++)
     { for( q=1; q<=3; q++)
       { int sum =0;
	    for(j=1; j<=3; j++)
         { 
           sum  = sum +  a[p][j]*b[j][q];
             }  
             c[p][q] = sum;
    
           printf("%d\t", c[p][q]);   }
        printf("\n");                  }
	
	break;


	default :
    printf("entred value is wrong !!!!");
	}  
	printf("do you want to continue y/n ? \n");
	fflush(stdin);
	scanf("%c", &option);
}
 while (option == 'y');
 getch();
 return 0;
		
}

void matrix()
    
    {
	printf("enter elements of 2nd matrix :\n");
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { scanf("%d",&b[i][j]);}}
    printf("entered value in matrix 2nd are:\n");
    for(i=1;i<=3;i++)
  { for(j=1;j<=3;j++)
  { printf("%d\t",b[i][j]);} 
    printf("\n"); }    	
    	
    	}

